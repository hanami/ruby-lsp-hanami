# typed: true
# frozen_string_literal: true

module RubyLsp
  module Hanami
    # Adds support for Dependency key autocompletion
    class Completion
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::CollectionResponseBuilder,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
          global_index: RubyIndexer::Index,
          workspace_path: String
        ).void
      end
      def initialize(response_builder, node_context, dispatcher, global_index, workspace_path)
        @response_builder = response_builder
        @node_context = node_context
        @global_index = global_index
        @workspace_path = workspace_path
        dispatcher.register(
          self,
          :on_call_node_enter
        )
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return unless @node_context.call_node&.receiver

        receiver_name = @node_context.call_node.receiver.name.to_s

        return if node.arguments.nil?

        call_node_args = T.cast(node.arguments, Prism::ArgumentsNode)

        return if call_node_args.arguments.nil?

        first_call_node_arg = T.must(call_node_args.arguments).first

        return if first_call_node_arg.nil? || !first_call_node_arg.is_a?(Prism::StringNode)

        args = first_call_node_arg.unescaped

        return unless RubyLsp::Hanami::CONTAINERS.include?(receiver_name.downcase)

        parents = args.split(".")[0, args.split(".").length - 1]
        needle = args.split(".").last
        hits = @global_index.constant_completion_candidates(needle, parents)

        if hits&.any?
          hits.each do |hit|
            next if hit_from_gem?(hit)

            hit = hit.first

            full_key = build_full_key(hit.name, parents)

            next unless RubyLsp::Hanami.key_present?(key: full_key)

            @response_builder << generate_completion_line_item(completion_candidate: hit.name)
          end
        end
        completion_candidates = RubyLsp::Hanami.completion_options(key: args)

        return if completion_candidates.empty?

        completion_candidates.each do |candidate|
          @response_builder << generate_completion_line_item(completion_candidate: candidate)
        end
      end

      private

      def hit_from_gem?(hit)
        hit.first&.uri.to_s.include?(".rbenv")
      end

      def build_full_key(hit_name, parents)
        formatted_name = hit_name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                                 .gsub(/([a-z])([A-Z])/, '\1_\2')
                                 .downcase

        (parents + [formatted_name]).join(".")
      end

      def generate_completion_line_item(completion_candidate:)
        Interface::CompletionItem.new(
          label: completion_candidate,
          detail: "A Hanami component.",
          documentation: Interface::MarkupContent.new(
            kind: Constant::MarkupKind::MARKDOWN,
            value: <<~MARKDOWN
              ### #{completion_candidate}
              A component within the **Hanami** dependency injection container.
              [View Documentation](https://hanakai.org/learn/hanami/v2.3/app/container-and-components)
            MARKDOWN
          ),
          label_details: Interface::CompletionItemLabelDetails.new(
            description: "A Hanami component."
          ),
          kind: Constant::CompletionItemKind::CLASS
        )
      end
    end
  end
end
