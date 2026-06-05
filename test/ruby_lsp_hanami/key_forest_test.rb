# frozen_string_literal: true

require_relative "../test_helper"

module RubyLsp
  module Hanami
    class KeyForestTest < Minitest::Test
      def setup
        @forest = KeyForest.new
      end

      def test_can_add_new_entries
        # adding to a new tree (using array key)
        @forest.add_entry(key: %w[actions users index], entry: "Entry1")
        assert_equal "Entry1", @forest.entry(key: "actions.users.index")
        assert @forest.key?(key: "actions.users.index")

        # adding to an existing tree (using string key)
        @forest.add_entry(key: "actions.users.show", entry: "Entry2")
        assert_equal "Entry2", @forest.entry(key: %w[actions users show])
        assert @forest.key?(key: "actions.users.show")

        # another new tree to ensure multiple roots work
        @forest.add_entry(key: "views.users.index", entry: "Entry3")
        assert_equal "Entry3", @forest.entry(key: "views.users.index")
      end

      def test_returns_correct_completion_options
        @forest.add_entry(key: "actions.users.index", entry: "Entry1")
        @forest.add_entry(key: "actions.users.show", entry: "Entry2")
        @forest.add_entry(key: "actions.posts.index", entry: "Entry3")
        @forest.add_entry(key: "views.users.index", entry: "Entry4")

        # partial root suggestion (tree index is nil)
        assert_equal ["actions"], @forest.completion_options(key: "act")
        assert_equal ["views"], @forest.completion_options(key: "v")

        # children of root (exact root match)
        assert_equal %w[posts users], @forest.completion_options(key: "actions").sort

        # children of sub-node (exact match of an intermediate node)
        assert_equal %w[index show], @forest.completion_options(key: "actions.users")

        # leaf node (no children available)
        assert_equal [], @forest.completion_options(key: "actions.users.index")
      end

      def test_key_is_blank
        @forest.add_entry(key: "actions.users.index", entry: "Entry1")
        assert_equal [], @forest.completion_options(key: "")
        assert_equal [], @forest.completion_options(key: [])
      end
    end
  end
end
