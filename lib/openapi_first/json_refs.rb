# frozen_string_literal: true

# This is a fork of the json_refs gem with some simplifications.
# The original code is available at https://github.com/tzmfreedom/json_refs
# This is a simplified version, which does not use chdir. See also https://github.com/tzmfreedom/json_refs/pull/11
# The code was originally written by Makoto Tajitsu with the MIT License.
#
# The MIT License (MIT)

# Copyright (c) 2017 Makoto Tajitsu

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'hana'
require 'json'
require 'yaml'

module JsonRefs
  class << self
    def call(doc)
      Dereferencer.new(Dir.pwd, doc).call
    end

    alias dereference call

    def load(filename)
      doc_dir = File.dirname(filename)
      doc = Loader.handle(filename)
      Dereferencer.new(doc_dir, doc).call
    end
  end

  module LocalRef
    module_function

    def call(path:, doc:)
      Hana::Pointer.new(path[1..]).eval(doc)
    end
  end

  module Loader
    module_function

    def handle(filename)
      body = File.read(filename)
      return JSON.parse(body) if File.extname(filename) == '.json'

      YAML.unsafe_load(body)
    end
  end

  class Dereferencer
    def initialize(doc_dir, doc)
      @doc = doc
      @doc_dir = doc_dir
    end

    def call(doc = @doc, keys = [])
      if doc.is_a?(Array)
        doc.each_with_index do |value, idx|
          call(value, keys + [idx])
        end
      elsif doc.is_a?(Hash)
        if doc.key?('$ref')
          dereference(keys, doc['$ref'])
        else
          doc.each do |key, value|
            call(value, keys + [key])
          end
        end
      end
      doc
    end

    private

    attr_reader :doc_dir

    def dereference(paths, referenced_path)
      key = paths.pop
      target = paths.inject(@doc) do |obj, k|
        obj[k]
      end
      value = follow_referenced_value(referenced_path)
      target[key] = value
    end

    def follow_referenced_value(referenced_path)
      value = referenced_value(referenced_path)
      return referenced_value(value['$ref']) if value.is_a?(Hash) && value.key?('$ref')

      value
    end

    def referenced_value(referenced_path)
      filepath, pointer = referenced_path.split('#')
      pointer&.prepend('#')
      return dereference_local(pointer) if filepath.empty?

      dereferenced_file = dereference_file(filepath)
      return dereferenced_file if pointer.nil?

      LocalRef.call(
        path: pointer,
        doc: dereferenced_file
      )
    end

    def dereference_local(referenced_path)
      LocalRef.call(path: referenced_path, doc: @doc)
    end

    def dereference_file(referenced_path)
      referenced_path = "#{doc_dir}/#{referenced_path}" unless File.absolute_path?(referenced_path)
      directory = File.dirname(referenced_path)

      referenced_doc = Loader.handle(referenced_path)
      Dereferencer.new(directory, referenced_doc).call
    end
  end
end
