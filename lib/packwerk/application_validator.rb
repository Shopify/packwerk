# typed: strict
# frozen_string_literal: true

require "constant_resolver"
require "pathname"
require "yaml"

module Packwerk
  # Checks the structure of the application and its packwerk configuration to make sure we can run a check and deliver
  # correct results.
  class ApplicationValidator
    extend T::Sig

    # This is a temporary API as we migrate validators to their own files.
    # Later, we can expose an API to get package sets to pass into validators when testing
    # This API would likely just be `PackageSet.load_all_from(configruation)`, but we might want to clean
    # up that API a bit (it looks like there are some unnecessary input variables).
    sig { returns(PackageSet) }
    attr_reader :package_set

    sig do
      params(
        config_file_path: String,
        configuration: Configuration,
        environment: String
      ).void
    end
    def initialize(config_file_path:, configuration:, environment:)
      @config_file_path = config_file_path
      @configuration = configuration
      @environment = environment
      package_set = PackageSet.load_all_from(
        @configuration.root_path,
        package_pathspec: Helpers.package_glob(configuration)
      )

      @package_set = T.let(package_set, PackageSet)
    end

    sig { returns(Result) }
    def check_all
      results = [
        CheckPackageManifestsForPrivacy.call(@package_set, @configuration),
        check_package_manifest_syntax,
        check_application_structure,
        check_acyclic_graph,
        check_package_manifest_paths,
        check_valid_package_dependencies,
        check_root_package_exists,
      ]

      Helpers.merge_results(results)
    end

    sig { returns(Result) }
    def check_package_manifest_syntax
      errors = []

      Helpers.package_manifests(@configuration).each do |f|
        hash = YAML.load_file(f)
        next unless hash

        known_keys = [
          *CheckPackageManifestsForPrivacy.permitted_keys,
          "enforce_dependencies",
          "dependencies",
          "metadata",
        ]
        unknown_keys = hash.keys - known_keys

        unless unknown_keys.empty?
          errors << "Unknown keys in #{f}: #{unknown_keys.inspect}\n"\
            "If you think a key should be included in your package.yml, please "\
            "open an issue in https://github.com/Shopify/packwerk"
        end

        if hash.key?("enforce_dependencies")
          unless [TrueClass, FalseClass].include?(hash["enforce_dependencies"].class)
            errors << "Invalid 'enforce_dependencies' option in #{f.inspect}: #{hash["enforce_dependencies"].inspect}"
          end
        end

        next unless hash.key?("dependencies")
        next if hash["dependencies"].is_a?(Array)

        errors << "Invalid 'dependencies' option in #{f.inspect}: #{hash["dependencies"].inspect}"
      end

      if errors.empty?
        Result.new(ok: true)
      else
        Result.new(ok: false, error_value: errors.join("\n---\n"))
      end
    end

    sig { returns(Result) }
    def check_application_structure
      resolver = ConstantResolver.new(
        root_path: @configuration.root_path.to_s,
        load_paths: @configuration.load_paths
      )

      begin
        resolver.file_map
        Result.new(ok: true)
      rescue => e
        Result.new(ok: false, error_value: e.message)
      end
    end

    sig { returns(Result) }
    def check_acyclic_graph
      edges = @package_set.flat_map do |package|
        package.dependencies.map { |dependency| [package, @package_set.fetch(dependency)] }
      end
      dependency_graph = Graph.new(*T.unsafe(edges))

      cycle_strings = build_cycle_strings(dependency_graph.cycles)

      if dependency_graph.acyclic?
        Result.new(ok: true)
      else
        Result.new(
          ok: false,
          error_value: <<~EOS
            Expected the package dependency graph to be acyclic, but it contains the following cycles:

            #{cycle_strings.join("\n")}
          EOS
        )
      end
    end

    sig { returns(Result) }
    def check_package_manifest_paths
      all_package_manifests = Helpers.package_manifests(@configuration, "**/")
      package_paths_package_manifests = Helpers.package_manifests(@configuration, Helpers.package_glob(@configuration))

      difference = all_package_manifests - package_paths_package_manifests

      if difference.empty?
        Result.new(ok: true)
      else
        Result.new(
          ok: false,
          error_value: <<~EOS
            Expected package paths for all package.ymls to be specified, but paths were missing for the following manifests:

            #{relative_paths(difference).join("\n")}
          EOS
        )
      end
    end

    sig { returns(Result) }
    def check_valid_package_dependencies
      packages_dependencies = Helpers.package_manifests_settings_for(@configuration, "dependencies")
        .delete_if { |_, deps| deps.nil? }

      packages_with_invalid_dependencies =
        packages_dependencies.each_with_object([]) do |(package, dependencies), invalid_packages|
          invalid_dependencies = dependencies.filter { |path| invalid_package_path?(path) }
          invalid_packages << [package, invalid_dependencies] if invalid_dependencies.any?
        end

      if packages_with_invalid_dependencies.empty?
        Result.new(ok: true)
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
          ok: false,
          error_value: <<~EOS
            These dependencies do not point to valid packages:

            #{error_locations.join("\n")}
          EOS
        )
      end
    end

    sig { returns(Result) }
    def check_root_package_exists
      root_package_path = File.join(@configuration.root_path, "package.yml")
      all_packages_manifests = Helpers.package_manifests(@configuration, Helpers.package_glob(@configuration))

      if all_packages_manifests.include?(root_package_path)
        Result.new(ok: true)
      else
        Result.new(
          ok: false,
          error_value: <<~EOS
            A root package does not exist. Create an empty `package.yml` at the root directory.
          EOS
        )
      end
    end

    private

    # Convert the cycles:
    #
    #   [[a, b, c], [b, c]]
    #
    # to the string:
    #
    #   ["a -> b -> c -> a", "b -> c -> b"]
    sig { params(cycles: T.untyped).returns(T::Array[String]) }
    def build_cycle_strings(cycles)
      cycles.map do |cycle|
        cycle_strings = cycle.map(&:to_s)
        cycle_strings << cycle.first.to_s
        "\t- #{cycle_strings.join(" → ")}"
      end
    end

    sig { params(list: T.untyped).returns(T.untyped) }
    def format_yaml_strings(list)
      list.sort.map { |p| "- \"#{p}\"" }.join("\n")
    end

    sig { params(paths: T::Array[String]).returns(T::Array[Pathname]) }
    def relative_paths(paths)
      paths.map { |path| Helpers.relative_path(@configuration, path) }
    end

    sig { params(path: T.untyped).returns(T::Boolean) }
    def invalid_package_path?(path)
      # Packages at the root can be implicitly specified as "."
      return false if path == "."

      package_path = File.join(@configuration.root_path, path, PackageSet::PACKAGE_CONFIG_FILENAME)
      !File.file?(package_path)
    end
  end
end
