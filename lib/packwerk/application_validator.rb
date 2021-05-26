# typed: false
# frozen_string_literal: true

require "active_support/inflector/inflections"
require "constant_resolver"
require "pathname"
require "yaml"

module Packwerk
  class ApplicationValidator
    def initialize(config_file_path:, configuration:)
      @config_file_path = config_file_path
      @configuration = configuration

      @application_load_paths = ApplicationLoadPaths.extract_relevant_paths
    end

    Result = Struct.new(:ok?, :error_value)

    def check_all
      results = [
        check_autoload_path_cache,
        check_package_manifests_for_privacy,
        check_package_manifest_syntax,
        check_application_structure,
        check_inflection_file,
        check_acyclic_graph,
        check_package_manifest_paths,
        check_valid_package_dependencies,
        check_root_package_exists,
      ]

      merge_results(results)
    end

    def check_autoload_path_cache
      expected = @application_load_paths
      actual = @configuration.load_paths
      if expected.sort == actual.sort
        Result.new(true)
      else
        Result.new(
          false,
          "Load path cache in #{@config_file_path} incorrect!\n"\
          "Paths missing from file:\n#{format_yaml_strings(expected - actual)}\n"\
          "Extraneous load paths in file:\n#{format_yaml_strings(actual - expected)}"
        )
      end
    end

    def check_package_manifests_for_privacy
      privacy_settings = package_manifests_settings_for("enforce_privacy")

      resolver = ConstantResolver.new(
        root_path: @configuration.root_path,
        load_paths: @configuration.load_paths
      )

      results = []

      privacy_settings.each do |config_file_path, setting|
        next unless setting.is_a?(Array)
        constants = setting

        assert_constants_can_be_loaded(constants)

        constant_locations = constants.map { |c| [c, resolver.resolve(c)&.location] }

        constant_locations.each do |name, location|
          results << if location
            check_private_constant_location(name, location, config_file_path)
          else
            private_constant_unresolvable(name, config_file_path)
          end
        end
      end

      merge_results(results, separator: "\n---\n")
    end

    def check_package_manifest_syntax
      errors = []

      package_manifests.each do |f|
        hash = YAML.load_file(f)
        next unless hash

        known_keys = %w(enforce_privacy enforce_dependencies public_path dependencies metadata)
        unknown_keys = hash.keys - known_keys

        unless unknown_keys.empty?
          errors << "Unknown keys in #{f}: #{unknown_keys.inspect}\n"\
            "If you think a key should be included in your package.yml, please "\
            "open an issue in https://github.com/Shopify/packwerk"
        end

        if hash.key?("enforce_privacy")
          unless [TrueClass, FalseClass, Array].include?(hash["enforce_privacy"].class)
            errors << "Invalid 'enforce_privacy' option in #{f.inspect}: #{hash["enforce_privacy"].inspect}"
          end
        end

        if hash.key?("enforce_dependencies")
          unless [TrueClass, FalseClass].include?(hash["enforce_dependencies"].class)
            errors << "Invalid 'enforce_dependencies' option in #{f.inspect}: #{hash["enforce_dependencies"].inspect}"
          end
        end

        if hash.key?("public_path")
          unless hash["public_path"].is_a?(String)
            errors << "'public_path' option must be a string in #{f.inspect}: #{hash["public_path"].inspect}"
          end
        end

        next unless hash.key?("dependencies")
        next if hash["dependencies"].is_a?(Array)

        errors << "Invalid 'dependencies' option in #{f.inspect}: #{hash["dependencies"].inspect}"
      end

      if errors.empty?
        Result.new(true)
      else
        Result.new(false, errors.join("\n---\n"))
      end
    end

    def check_application_structure
      resolver = ConstantResolver.new(
        root_path: @configuration.root_path.to_s,
        load_paths: @configuration.load_paths
      )

      begin
        resolver.file_map
        Result.new(true)
      rescue => e
        Result.new(false, e.message)
      end
    end

    def check_inflection_file
      inflections_file = @configuration.inflections_file

      application_inflections = ActiveSupport::Inflector.inflections
      packwerk_inflections = Packwerk::Inflector.from_file(inflections_file).inflections

      results = %i(plurals singulars uncountables humans acronyms).map do |type|
        expected = application_inflections.public_send(type).to_set
        actual = packwerk_inflections.public_send(type).to_set

        if expected == actual
          Result.new(true)
        else
          missing_msg = unless (expected - actual).empty?
            "Expected #{type} to be specified in file: #{expected - actual}"
          end
          extraneous_msg = unless (actual - expected).empty?
            "Extraneous #{type} was specified in file: #{actual - expected}"
          end
          Result.new(
            false,
            [missing_msg, extraneous_msg].join("\n")
          )
        end
      end

      merge_results(
        results,
        separator: "\n",
        errors_headline: "Inflections specified in #{inflections_file} don't line up with application!\n"
      )
    end

    def check_acyclic_graph
      edges = package_set.flat_map do |package|
        package.dependencies.map { |dependency| [package, package_set.fetch(dependency)] }
      end
      dependency_graph = Packwerk::Graph.new(*edges)

      # Convert the cycle
      #
      #   [a, b, c]
      #
      # to the string
      #
      #   a -> b -> c -> a
      #
      cycle_strings = dependency_graph.cycles.map do |cycle|
        cycle_strings = cycle.map(&:to_s)
        cycle_strings << cycle.first.to_s
        "\t- #{cycle_strings.join(" → ")}"
      end

      if dependency_graph.acyclic?
        Result.new(true)
      else
        Result.new(
          false,
          <<~EOS
            Expected the package dependency graph to be acyclic, but it contains the following cycles:

            #{cycle_strings.join("\n")}
          EOS
        )
      end
    end

    def check_package_manifest_paths
      all_package_manifests = package_manifests("**/")
      package_paths_package_manifests = package_manifests(package_glob)

      difference = all_package_manifests - package_paths_package_manifests

      if difference.empty?
        Result.new(true)
      else
        Result.new(
          false,
          <<~EOS
            Expected package paths for all package.ymls to be specified, but paths were missing for the following manifests:

            #{relative_paths(difference).join("\n")}
          EOS
        )
      end
    end

    def check_valid_package_dependencies
      packages_dependencies = package_manifests_settings_for("dependencies")
        .delete_if { |_, deps| deps.nil? }

      packages_with_invalid_dependencies =
        packages_dependencies.each_with_object([]) do |(package, dependencies), invalid_packages|
          invalid_dependencies = dependencies.filter { |path| invalid_package_path?(path) }
          invalid_packages << [package, invalid_dependencies] if invalid_dependencies.any?
        end

      if packages_with_invalid_dependencies.empty?
        Result.new(true)
      else
        error_locations = packages_with_invalid_dependencies.map do |package, invalid_dependencies|
          package ||= @configuration.root_path
          package_path = Pathname.new(package).relative_path_from(@configuration.root_path)
          all_invalid_dependencies = invalid_dependencies.map { |d| "  - #{d}" }

          <<~EOS
            #{package_path}:
            #{all_invalid_dependencies.join("\n")}
          EOS
        end

        Result.new(
          false,
          <<~EOS
            These dependencies do not point to valid packages:

            #{error_locations.join("\n")}
          EOS
        )
      end
    end

    def check_root_package_exists
      root_package_path = File.join(@configuration.root_path, "package.yml")
      all_packages_manifests = package_manifests(package_glob)

      if all_packages_manifests.include?(root_package_path)
        Result.new(true)
      else
        Result.new(
          false,
          <<~EOS
            A root package does not exist. Create an empty `package.yml` at the root directory.
          EOS
        )
      end
    end

    private

    def package_manifests_settings_for(setting)
      package_manifests.map { |f| [f, (YAML.load_file(File.join(f)) || {})[setting]] }
    end

    def format_yaml_strings(list)
      list.sort.map { |p| "- \"#{p}\"" }.join("\n")
    end

    def package_glob
      @configuration.package_paths || "**"
    end

    def package_manifests(glob_pattern = package_glob)
      PackageSet.package_paths(@configuration.root_path, glob_pattern)
        .map { |f| File.realpath(f) }
    end

    def relative_paths(paths)
      paths.map { |path| relative_path(path) }
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(@configuration.root_path)
    end

    def invalid_package_path?(path)
      # Packages at the root can be implicitly specified as "."
      return false if path == "."

      package_path = File.join(@configuration.root_path, path, Packwerk::PackageSet::PACKAGE_CONFIG_FILENAME)
      !File.file?(package_path)
    end

    def assert_constants_can_be_loaded(constants)
      constants.each(&:constantize)
      nil
    end

    def private_constant_unresolvable(name, config_file_path)
      explicit_filepath = (name.start_with?("::") ? name[2..-1] : name).underscore + ".rb"

      Result.new(
        false,
        "'#{name}', listed in #{config_file_path}, could not be resolved.\n"\
        "This is probably because it is an autovivified namespace - a namespace module that doesn't have a\n"\
        "file explicitly defining it. Packwerk currently doesn't support declaring autovivified namespaces as\n"\
        "private. Add a #{explicit_filepath} file to explicitly define the constant."
      )
    end

    def check_private_constant_location(name, location, config_file_path)
      declared_package = package_set.package_from_path(relative_path(config_file_path))
      constant_package = package_set.package_from_path(location)

      if constant_package == declared_package
        Result.new(true)
      else
        Result.new(
          false,
          "'#{name}' is declared as private in the '#{declared_package}' package but appears to be "\
          "defined\nin the '#{constant_package}' package. Packwerk resolved it to #{location}."
        )
      end
    end

    def package_set
      @package_set ||= Packwerk::PackageSet.load_all_from(@configuration.root_path, package_pathspec: package_glob)
    end

    def merge_results(results, separator: "\n===\n", errors_headline: "")
      results.reject!(&:ok?)

      if results.empty?
        Result.new(true)
      else
        Result.new(
          false,
          errors_headline + results.map(&:error_value).join(separator)
        )
      end
    end
  end
end
