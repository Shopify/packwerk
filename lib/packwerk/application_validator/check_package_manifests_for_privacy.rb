# typed: strict
# frozen_string_literal: true

module Packwerk
  class ApplicationValidator
    module CheckPackageManifestsForPrivacy
      class << self
        extend T::Sig

        sig { params(package_set: PackageSet, configuration: Configuration).returns(Result) }
        def call(package_set, configuration)
          privacy_settings = Helpers.package_manifests_settings_for(configuration, "enforce_privacy")

          resolver = ConstantResolver.new(
            root_path: configuration.root_path,
            load_paths: configuration.load_paths
          )

          results = T.let([], T::Array[Result])

          privacy_settings.each do |config_file_path, setting|
            results << check_enforce_privacy_setting(config_file_path, setting)
            next unless setting.is_a?(Array)

            constants = setting

            results += assert_constants_can_be_loaded(constants, config_file_path)

            constant_locations = constants.map { |c| [c, resolver.resolve(c)&.location] }

            constant_locations.each do |name, location|
              results << if location
                check_private_constant_location(configuration, package_set, name, location, config_file_path)
              else
                private_constant_unresolvable(name, config_file_path)
              end
            end
          end

          public_path_settings = Helpers.package_manifests_settings_for(configuration, "public_path")
          public_path_settings.each do |config_file_path, setting|
            results << check_public_path(config_file_path, setting)
          end

          Helpers.merge_results(results, separator: "\n---\n")
        end

        sig { returns(T::Array[String]) }
        def permitted_keys
          ["public_path", "enforce_privacy", "public_constants"]
        end

        private

        sig do
          params(config_file_path: String, setting: T.untyped).returns(Result)
        end
        def check_public_path(config_file_path, setting)
          if setting.is_a?(String) || setting.nil?
            Result.new(ok: true)
          else
            Result.new(
              ok: false,
              error_value: "'public_path' option must be a string in #{config_file_path.inspect}: #{setting.inspect}"
            )
          end
        end

        sig do
          params(config_file_path: String, setting: T.untyped).returns(Result)
        end
        def check_enforce_privacy_setting(config_file_path, setting)
          if [TrueClass, FalseClass, Array, NilClass].include?(setting.class)
            Result.new(ok: true)
          else
            Result.new(
              ok: false,
              error_value: "Invalid 'enforce_privacy' option in #{config_file_path.inspect}: #{setting.inspect}"
            )
          end
        end

        sig do
          params(configuration: Configuration, package_set: PackageSet, name: T.untyped, location: T.untyped,
            config_file_path: T.untyped).returns(Result)
        end
        def check_private_constant_location(configuration, package_set, name, location, config_file_path)
          declared_package = package_set.package_from_path(Helpers.relative_path(configuration, config_file_path))
          constant_package = package_set.package_from_path(location)

          if constant_package == declared_package
            Result.new(ok: true)
          else
            Result.new(
              ok: false,
              error_value: "'#{name}' is declared as private in the '#{declared_package}' package but appears to be "\
                "defined\nin the '#{constant_package}' package. Packwerk resolved it to #{location}."
            )
          end
        end

        sig { params(constants: T.untyped, config_file_path: String).returns(T::Array[Result]) }
        def assert_constants_can_be_loaded(constants, config_file_path)
          constants.map do |constant|
            if !constant.start_with?("::")
              error_value = "'#{constant}', listed in the 'enforce_privacy' option" \
                " in #{config_file_path}, is invalid.\nPrivate constants need to be" \
                " prefixed with the top-level namespace operator `::`."
              Result.new(
                ok: false,
                error_value: error_value
              )
            else
              constant.try(&:constantize) && Result.new(ok: true)
            end
          end
        end

        sig { params(name: T.untyped, config_file_path: T.untyped).returns(Result) }
        def private_constant_unresolvable(name, config_file_path)
          explicit_filepath = (name.start_with?("::") ? name[2..-1] : name).underscore + ".rb"

          Result.new(
            ok: false,
            error_value: "'#{name}', listed in #{config_file_path}, could not be resolved.\n"\
              "This is probably because it is an autovivified namespace - a namespace module that doesn't have a\n"\
              "file explicitly defining it. Packwerk currently doesn't support declaring autovivified namespaces as\n"\
              "private. Add a #{explicit_filepath} file to explicitly define the constant."
          )
        end
      end
    end
  end
end
