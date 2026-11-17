# frozen_string_literal: true

# Reads KEY=VALUE lines from a .env file. Only the integration spec uses it; the gem never reads ENV.
module EnvFile
  module_function

  def load(path)
    return {} unless File.exist?(path)

    File.readlines(path, chomp: true).each_with_object({}) do |line, values|
      next if line.strip.empty? || line.lstrip.start_with?("#")

      key, value = line.split("=", 2)
      values[key.strip] = value.to_s.strip.delete_prefix('"').delete_suffix('"')
    end
  end
end
