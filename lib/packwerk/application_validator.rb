# typed: false
# frozen_string_literal: true

require "active_support/inflector/inflections"
require "constant_resolver"
require "pathname"
require "yaml"

require "packwerk/package_set"
require "packwerk/graph"
require "packwerk/inflector"
require "packwerk/application_load_paths"

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

      results.reject!(&:ok?)

      if results.empty?
        Result.new(true)
      else
        Result.new(
          false,
          results.map(&:error_value).join("\n===\n")
        )
      end
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

      autoload_paths = @configuration.load_paths

      resolver = ConstantResolver.new(
        root_path: @configuration.root_path,
        load_paths: autoload_paths
      )

      errors = []

      privacy_settings.each do |filepath, setting|
        next unless setting.is_a?(Array)

        setting.each do |constant|
          # make sure the constant can be loaded
          constant.constantize # rubocop:disable Sorbet/ConstantsFromStrings
          context = resolver.resolve(constant)

          unless context
            errors << "#{constant}, listed in #{filepath.inspect}, could not be resolved"
            next
          end

          expected_filename = constant.underscore + ".rb"

          # We don't support all custom inflections yet, so we may accidentally resolve constants to the
          # file that defines their parent namespace. This restriction makes sure that we don't.
          next if context.location.end_with?(expected_filename)

          errors << "Explicitly private constants need to have their own files.\n"\
            "#{constant}, listed in #{filepath.inspect}, was resolved to #{context.location.inspect}.\n"\
            "It should be in something like #{expected_filename.inspect}"
        end
      end

      if errors.empty?
        Result.new(true)
      else
        Result.new(false, errors.join("\n---\n"))
      end
    end

    def check_package_manifest_syntax
      errors = []

      package_manifests(package_glob).each do |f|
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
            errors << "Invalid 'enforce_privacy' option in #{f.inspect}: #{hash['enforce_privacy'].inspect}"
          end
        end

        if hash.key?("enforce_dependencies")
          unless [TrueClass, FalseClass].include?(hash["enforce_dependencies"].class)
            errors << "Invalid 'enforce_dependencies' option in #{f.inspect}: #{hash['enforce_dependencies'].inspect}"
          end
        end

        if hash.key?("public_path")
          unless hash["public_path"].is_a?(String)
            errors << "'public_path' option must be a string in #{f.inspect}: #{hash['public_path'].inspect}"
          end
        end

        next unless hash.key?("dependencies")
        next if hash["dependencies"].is_a?(Array)

        errors << "Invalid 'dependencies' option in #{f.inspect}: #{hash['dependencies'].inspect}"
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

      errors = results.reject(&:ok?)

      if errors.empty?
        Result.new(true)
      else
        Result.new(
          false,
          "Inflections specified in #{inflections_file} don't line up with application!\n" +
            errors.map(&:error_value).join("\n")
        )
      end
    end

    def check_acyclic_graph
      packages = Packwerk::PackageSet.load_all_from(@configuration.root_path)

      edges = packages.flat_map do |package|
        package.dependencies.map { |dependency| [package, packages.fetch(dependency)] }
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
        "\t- #{cycle_strings.join(' → ')}"
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
      package_manifests(package_glob)
        .map { |f| [f, (YAML.load_file(File.join(f)) || {})[setting]] }
    end

    def format_yaml_strings(list)
      list.sort.map { |p| "- \"#{p}\"" }.join("\n")
    end

    def package_glob
      @configuration.package_paths || "**"
    end

    def package_manifests(glob_pattern)
      PackageSet.package_paths(@configuration.root_path, glob_pattern)
        .map { |f| File.realpath(f) }
    end

    def relative_paths(paths)
      paths.map { |path| Pathname.new(path).relative_path_from(@configuration.root_path) }
    end

    def invalid_package_path?(path)
      # Packages at the root can be implicitly specified as "."
      return false if path == "."

      package_path = File.join(@configuration.root_path, path, Packwerk::PackageSet::PACKAGE_CONFIG_FILENAME)
      !File.file?(package_path)
    end
  end
end
