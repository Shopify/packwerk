# typed: true
# frozen_string_literal: true

class YamlFile
  def initialize(path)
    @path = path
  end

  def merge(hash)
    merged_data = recursive_merge(read_or_create, hash)
    write(merged_data)
  end

  private

  attr_reader :path

  def read_or_create
    FileUtils.mkpath(File.dirname(path))
    FileUtils.touch(path)
    YAML.load_file(path) || {}
  end

  def write(data)
    File.open(path, "w") { |f| YAML.dump(data, f) }
  end

  def recursive_merge(hash, other_hash)
    hash.merge(other_hash) do |_, old_value, new_value|
      if old_value.is_a?(Hash) && new_value.is_a?(Hash)
        recursive_merge(old_value, new_value)
      elsif old_value.is_a?(Array)
        old_value + Array(new_value)
      else
        new_value
      end
    end
  end
end
