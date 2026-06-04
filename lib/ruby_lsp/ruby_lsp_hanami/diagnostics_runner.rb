# typed: true
# frozen_string_literal: true

require "prism"

module RubyLsp
  module Hanami
    # A helper class that handles sending client side diagnostics
    class HanamiDiagnosticsRunner
      extend T::Sig
      include RubyLsp::Requests::Support::Formatter

      sig { params(message_queue: Thread::Queue, index: RubyIndexer::Index).void }
      def initialize(message_queue, index)
        @message_queue = message_queue
        @index = index
      end

      sig { params(uri: URI::Generic, document: RubyLsp::Document).returns(String) }
      def run_formatting(uri, document)
        run_diagnostic(uri, document)
        document.source
      end

      sig { params(uri: URI::Generic, document: RubyLsp::Document).void }
      def run_diagnostic(uri, document)
        ast = Prism.parse(document.source).value
        ast_root = ast.statements.body.first # this is an array, idk what the other elements would be in it though
        deps_argument = hunt_for_deps_arg(ast_root)

        return if deps_argument.nil?

        given_key = deps_argument.unescaped

        # if we have a Deps argument, regardless of if that key exists or not,
        # if Prism cannot return a location for the key, just skip on showing the
        # diagnostic
        return if deps_argument.opening_loc.nil? || deps_argument.closing_loc.nil?

        starting_location = T.must(deps_argument.opening_loc)
        ending_location = T.must(deps_argument.closing_loc)

        # if there are no diagnostic errors, push an empty list to clear any previously
        # sent diagnostics for the file
        # @see https://dart.googlesource.com/sdk/%2B/fe6fc7803dd69c2ea4a1471d5898b4f4e13c0f99/pkg/analysis_server/tool/lsp_spec/lsp_specification.md#publishdiagnostics-notification-arrow_left
        diagnostics = if RubyLsp::Hanami.container_key?(key: given_key)
                        []
                      else
                        [
                          RubyLsp::Interface::Diagnostic.new(
                            # message: "Key: \"#{given_key}\" not found. \n Newline",
                            message: "Key: \"#{given_key}\" not found.",
                            range: RubyLsp::Interface::Range.new(
                              start: RubyLsp::Interface::Position.new(line: starting_location.start_line - 1,
                                                                      character: starting_location.start_column),
                              end: RubyLsp::Interface::Position.new(line: ending_location.end_line - 1,
                                                                    character: ending_location.end_column)
                            ),
                            severity: Constant::DiagnosticSeverity::ERROR
                          )
                        ]
                      end

        @message_queue.push(
          method: "textDocument/publishDiagnostics",
          params: RubyLsp::Interface::PublishDiagnosticsParams.new(
            uri: uri,
            diagnostics: diagnostics,
            version: 1 # ?
          )
        )
      end

      private

      # intentionally casting as "T.untyped" instead of writing a long list of whatever could be nested in a
      # Prism AST, and potentially missing something causing a runtime halt
      sig { params(node: T.untyped).returns(T.nilable(Prism::StringNode)) }
      def hunt_for_deps_arg(node)
        node = node.first if node.is_a?(Array)

        # sorbet ... :/
        if node.is_a?(Prism::CallNode) && node.name.to_s == "include" && !node.arguments.nil?
          # the arguments passed to the 'include' CallNode
          call_node_args = T.cast(node.arguments, Prism::ArgumentsNode)

          # if 'include' was passed a CallNode ('Deps')
          if !call_node_args.arguments.nil? && call_node_args.arguments.first.is_a?(Prism::CallNode)
            # get a reference to the Deps CallNode
            first_call_node_arg = T.cast(call_node_args.arguments.first, Prism::CallNode)

            # TODO: this is the case when we encounter something like this:
            # 'include Deps[]'
            #
            # should we be returning custom errors or something to show edge case diagnostics in the editor?
            # e.g. "Deps must have an argument passed"
            return nil if first_call_node_arg.arguments.nil?

            # lol
            first_call_node_arg_args = T.must(first_call_node_arg.arguments)

            return nil unless first_call_node_arg.receiver.is_a?(Prism::ConstantReadNode)

            # confirm that the reference we have is indeed 'Deps',
            # and return the 'Deps' CallNode's arguments, else nil
            deps_arguments =  if T.cast(first_call_node_arg.receiver, Prism::ConstantReadNode).name.to_s == "Deps"
                                first_call_node_arg_args.arguments.first
                              else
                                nil
                              end

            return nil unless deps_arguments.is_a?(Prism::StringNode)

            return deps_arguments
          end

          nil
        end

        hunt_for_deps_arg(node.body) if node.respond_to?(:body) && !node.body.nil? && !node.is_a?(Prism::CallNode)
      end
    end
  end
end
