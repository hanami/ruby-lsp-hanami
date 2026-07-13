# frozen_string_literal: true

module RubyLsp
  module Hanami
    # top level comment
    class KeyForest
      attr_reader :trees

      def initialize
        @trees = {}
      end

      def key?(key:)
        return false if empty_key?(key: key)

        key_parts = create_key_parts(key: key)

        node = @trees.dig(*key_parts)
        !node.nil? && node.key?(:entry)
      end

      def key_present?(key:)
        return false if empty_key?(key: key)

        key_parts = create_key_parts(key: key)
        !@trees.dig(*key_parts).nil?
      end

      def add_entry(key:, entry:)
        key_parts = create_key_parts(key: key)

        position = key_parts.inject(@trees) do |curr, part|
          curr[part] ||= {}
        end

        position[:entry] = entry
      end

      def entry(key:)
        return if empty_key?(key: key)

        key_parts = create_key_parts(key: key)
        node = @trees.dig(*key_parts)

        node ? node[:entry] : nil
      end

      # find and return what the next part of a container key could be
      def completion_options(key:)
        return [] if empty_key?(key: key)

        key_parts = create_key_parts(key: key)

        if key_parts.length == 1
          keys = @trees.keys.select { |k| k.is_a?(String) }

          # if the given single key is an exact match, return its children as completion options
          return @trees[key_parts.first].keys.select { |k| k.is_a?(String) } if keys.include?(key_parts.first)

          # else give completion options for the key itself
          return keys.select { |k| k.start_with?(key_parts.first) }
        end

        node = @trees.dig(*key_parts)

        return [] if node.nil?

        node.keys.select { |k| k.is_a?(String) }
      end

      def forest_fire
        @trees = {}
      end

      def delete_by_uri(uri)
        uri_str = uri.to_s
        delete_from_node(@trees, uri_str)
      end

      private

      def delete_from_node(node, uri_str)
        node.each do |key, child|
          next if key == :entry

          delete_from_node(child, uri_str)

          child.delete(:entry) if child[:entry] && child.dig(:entry).uri.to_s == uri_str

          node.delete(key) if child.empty?
        end
      end

      # provide a way to pass a traditional key (e.g.: 'how.we.encounter.it'), but allow for
      # the caller to optimize and pass an array to prevent needless splitting
      def create_key_parts(key:)
        key.is_a?(String) ? key.split(".") : key
      end

      def empty_key?(key:)
        key.is_a?(String) ? key == "" : key.empty?
      end
    end
  end
end
