# frozen_string_literal: true

require_relative "../test_helper"

module RubyLsp
  module Hanami
    class IndexingEnhancementTest < Minitest::Test
      include RubyLsp::TestHelper

      def setup
        RubyLsp::Hanami.clear_entries
      end

      def test_discovers_class_nodes
        source = <<~RUBY
          # typed: false
          module Fake
            class MyClass
              def call; end
            end
          end
        RUBY

        with_server(source, URI("file://#{Dir.pwd}/fake.rb")) do |_server, _uri|
          assert_equal(true, RubyLsp::Hanami.container_key?(key: "fake.my_class"))
        end
      end

      # sort of covered by DefinitionTest#test_deps_non_standard_definition,
      # this test is complimentary to that one
      def test_discovers_operation_call_functions
        source = <<~RUBY
          # typed: false
          module Fake
            class MyOperation < Hanami::Operation
              def call; end
            end
          end
        RUBY

        with_server(source, URI("file://#{Dir.pwd}/fake.rb")) do |_server, _uri|
          assert_equal(true, RubyLsp::Hanami.container_key?(key: "fake.my_operation"))
          assert_equal(1, RubyLsp::Hanami.get_entries(key: "fake.my_operation").size)
        end
      end

      def test_skips_indexing_with_auto_register_false
        source = <<~RUBY
          # typed: false
          # auto_register: false
          module Fake
            class MyClass
              def call; end
            end
          end
        RUBY

        with_server(source, URI("file://#{Dir.pwd}/fake.rb")) do |_server, _uri|
          assert_equal(false, RubyLsp::Hanami.container_key?(key: "fake.my_class"))
        end
      end

      def test_removes_existing_entries_when_re_indexed_with_auto_register_false
        uri = URI("file://#{Dir.pwd}/fake.rb")
        
        source = <<~RUBY
          # typed: false
          module Fake
            class MyClass
              def call; end
            end
          end
        RUBY

        with_server(source, uri) do |_server, _uri|
          assert_equal(true, RubyLsp::Hanami.container_key?(key: "fake.my_class"))
        end

        new_source = <<~RUBY
          # typed: false
          # auto_register: false
          module Fake
            class MyClass
              def call; end
            end
          end
        RUBY

        with_server(new_source, uri) do |_server, _uri|
          assert_equal(false, RubyLsp::Hanami.container_key?(key: "fake.my_class"))
        end
      end

      def test_skips_indexing_for_files_in_lib_directory
        source = <<~RUBY
          # typed: false
          module Fake
            class MyClass
              def call; end
            end
          end
        RUBY

        with_server(source, URI("file://#{Dir.pwd}/lib/fake.rb")) do |_server, _uri|
          assert_equal(false, RubyLsp::Hanami.container_key?(key: "fake.my_class"))
        end
      end
    end
  end
end
