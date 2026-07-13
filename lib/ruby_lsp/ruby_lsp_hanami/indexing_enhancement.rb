# frozen_string_literal: true
# typed: true

module RubyLsp
  module Hanami
    include Kernel

    # The IndexingEnhancement adds to and extends the default RubyIndexer provided by the Ruby LSP
    # @see https://shopify.github.io/ruby-lsp/add-ons.html#dealing-with-declaration-dsls
    class IndexingEnhancement < RubyIndexer::Enhancement
      extend T::Sig

      # RubyIndexer::Enhancement doesn't provide on_class_node_enter by default.
      # hook into the existing indexer and manually create entries for class nodes
      def initialize(listener)
        super(listener)
        @uri = @listener.instance_variable_get(:@uri)
        @index = @listener.instance_variable_get(:@index)

        # clear any existing records for this file
        # useful in scenarios where 'opt-out' behavior is added (e.g. `# auto_register: false`)
        RubyLsp::Hanami.delete_entries_for_uri(@uri) if within_workspace?(@uri)

        original_method = @listener.method(:on_class_node_enter)

        enhancement = self

        @listener.define_singleton_method(:on_class_node_enter) do |node|
          result = original_method.call(node)
          return if enhancement.send(:skip_indexing?)

          class_entry = RubyIndexer::Entry::Class.new(@index.configuration, [], @uri, node.location, node.name,
                                                      node.comments, "")

          RubyLsp::Hanami.add_key_entry(result, class_entry)
        end
      end

      sig { params(_call_node: Prism::CallNode).void }
      def on_call_node_enter(_call_node)
        return if skip_indexing?

        owner = @listener.current_owner
        component_parts = owner.name.split("::")
        component_parts.shift if slice?(@uri)
        componentized_name = component_parts.join(".")

        # edge case for Operations, using #call as potential entry
        if owner.respond_to?(:parent_class) && owner.parent_class&.include?("::Operation")
          call_defs = @index.method_completion_candidates("call", owner.name)
          RubyLsp::Hanami.add_key_entry(componentized_name, call_defs.first) unless call_defs.empty?
        end

        # add all indexed entries as component keys
        RubyLsp::Hanami.add_key_entry(componentized_name, owner)
      end

      private

      sig { params(uri: URI::Generic).returns(T::Boolean) }
      def slice?(uri)
        uri.to_s.include?("slices/")
      end

      def skip_indexing?
        return true unless @listener.current_owner

        # if file is outside of the app
        return true unless within_workspace?(@uri)

        # if file is in the top level "lib/" directory
        # @see: https://hanakai.org/learn/hanami/v2.3/app/container-and-components#opting-out-of-the-container
        return true if @uri.path.include?("#{@index.configuration.instance_variable_get(:@workspace_path)}/lib/")

        # if opting out the container
        return true if discovered_auto_register_opt_out_comment?

        false
      end

      def within_workspace?(path)
        path.to_s.include?(@index.configuration.instance_variable_get(:@workspace_path))
      end

      def discovered_auto_register_opt_out_comment?
        file_comments = @listener.instance_variable_get(:@comments_by_line)

        file_comments&.values&.any? do |comment|
          comment.location.slice.include?("auto_register: false")
        end
      end
    end
  end
end
