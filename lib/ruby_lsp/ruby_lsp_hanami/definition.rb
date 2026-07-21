# typed: true
# frozen_string_literal: true

module RubyLsp
  module Hanami
    # Adds support for 'click to definition'
    class Definition
      extend T::Sig
      include Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::CollectionResponseBuilder,
          node_context: NodeContext,
          index: RubyIndexer::Index,
          dispatcher: Prism::Dispatcher,
          workspace_path: String,
        ).void
      end
      def initialize(response_builder, node_context, index, dispatcher, workspace_path)
        @response_builder = response_builder
        @node_context = node_context
        @index = index
        @workspace_path = workspace_path

        dispatcher.register(self, :on_string_node_enter)
      end

      sig { params(node: Prism::StringNode).void }
      def on_string_node_enter(node)
        # collect possible matches
        entries = if RubyLsp::Hanami::CONTAINERS.include?(@node_context.call_node.receiver.name.to_s.downcase)
                    RubyLsp::Hanami.get_entries(key: node.content, lsp_index: @index)
                  else
                    []
                  end

        entries.each do |entry|
          loc = entry.location
          next unless entry.file_path.include?(@workspace_path)

          @response_builder << Interface::Location.new(
            uri: URI::Generic.from_path(
              path: entry.file_path,
              fragment: "L#{loc.start_line},#{loc.start_column + 1}-#{loc.end_line},#{loc.end_column + 1}"
            ),
            range: range_from_location(entry.location)
          )
        end
      end
    end
  end
end
