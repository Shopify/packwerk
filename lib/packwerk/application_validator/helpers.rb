# typed: strict
# frozen_string_literal: true

module Packwerk
  class ApplicationValidator
    module Helpers
      class << self
        extend T::Sig

        sig { params(configuration: Configuration, setting: T.untyped).returns(T.untyped) }
        def package_manifests_settings_for(configuration, setting)
          package_manifests(configuration).map { |f| [f, (YAML.load_file(File.join(f)) || {})[setting]] }
        end

        sig do
          params(configuration: Configuration,
            glob_pattern: T.nilable(T.any(T::Array[String], String))).returns(T::Array[String])
        end
        def package_manifests(configuration, glob_pattern = nil)
          glob_pattern ||= package_glob(configuration)
          PackageSet.package_paths(configuration.root_path, glob_pattern, configuration.exclude)
            .map { |f| File.realpath(f) }
        end

        sig { params(configuration: Configuration).returns(T.any(T::Array[String], String)) }
        def package_glob(configuration)
          configuration.package_paths || "**"
        end

        sig do
          params(results: T::Array[Result], separator: String, errors_headline: String).returns(Result)
        end
        def merge_results(results, separator: "\n===\n", errors_headline: "")
          results.reject!(&:ok?)

          if results.empty?
            Result.new(ok: true)
          else
            Result.new(
              ok: false,
              error_value: errors_headline + results.map(&:error_value).join(separator)
            )
          end
        end

        sig { params(configuration: Configuration, path: String).returns(Pathname) }
        def relative_path(configuration, path)
          Pathname.new(path).relative_path_from(configuration.root_path)
        end
      end
    end

    private_constant :Helpers
  end
end
