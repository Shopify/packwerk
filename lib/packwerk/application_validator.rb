# typed: strict
# frozen_string_literal: true

require "constant_resolver"
require "pathname"
require "yaml"

module Packwerk
  # Checks the structure of the application and its packwerk configuration to make sure we can run a check and deliver
  # correct results.
  class ApplicationValidator
    include Validator
    extend T::Sig

    sig { params(package_set: PackageSet, configuration: Configuration).returns(ApplicationValidator::Result) }
    def check_all(package_set, configuration)
      results = Validator.all.flat_map { |validator| validator.call(package_set, configuration) }
      merge_results(results)
    end

    sig { override.params(package_set: PackageSet, configuration: Configuration).returns(ApplicationValidator::Result) }
    def call(package_set, configuration)
      results = [
        check_package_manifest_syntax(configuration),
        check_application_structure(configuration),
        check_acyclic_graph(package_set),
        check_package_manifest_paths(configuration),
        check_valid_package_dependencies(configuration),
        check_root_package_exists(configuration),
      ]

      merge_results(results)
    end

    sig { override.returns(T::Array[String]) }
    def permitted_keys
      [
        "enforce_dependencies",
        "dependencies",
        "metadata",
      ]
    end

    sig { params(configuration: Configuration).returns(Result) }
    def check_package_manifest_syntax(configuration)
      errors = []

      package_manifests(configuration).each do |f|
        hash = YAML.load_file(f)
        next unless hash

        known_keys = Validator.all.flat_map(&:permitted_keys)
        unknown_keys = hash.keys - known_keys

        unless unknown_keys.empty?
          errors << "Unknown keys in #{f}: #{unknown_keys.inspect}\n"\
            "If you think a key should be included in your package.yml, please "\
            "open an issue in https://github.com/Shopify/packwerk"
        end

        if hash.key?("enforce_dependencies")
          unless [TrueClass, FalseClass, "strict"].include?(hash["enforce_dependencies"].class)
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

    sig { params(configuration: Configuration).returns(Result) }
    def check_application_structure(configuration)
      resolver = ConstantResolver.new(
        root_path: configuration.root_path.to_s,
        load_paths: configuration.load_paths
      )

      begin
        resolver.file_map
        Result.new(ok: true)
      rescue => e
        Result.new(ok: false, error_value: e.message)
      end
    end

    sig { params(package_set: PackageSet).returns(Result) }
    def check_acyclic_graph(package_set)
      edges = package_set.flat_map do |package|
        package.dependencies.map { |dependency| [package.name, T.must(package_set.fetch(dependency)).name] }
      end

      dependency_graph = Graph.new(edges)

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

    sig { params(configuration: Configuration).returns(Result) }
    def check_package_manifest_paths(configuration)
      all_package_manifests = package_manifests(configuration, "**/")
      package_paths_package_manifests = package_manifests(configuration, package_glob(configuration))

      difference = all_package_manifests - package_paths_package_manifests

      if difference.empty?
        Result.new(ok: true)
      else
        Result.new(
          ok: false,
          error_value: <<~EOS
            Expected package paths for all package.ymls to be specified, but paths were missing for the following manifests:

            #{relative_paths(configuration, difference).join("\n")}
          EOS
        )
      end
    end

    sig { params(configuration: Configuration).returns(Result) }
    def check_valid_package_dependencies(configuration)
      packages_dependencies = package_manifests_settings_for(configuration, "dependencies")
        .delete_if { |_, deps| deps.nil? }

      packages_with_invalid_dependencies =
        packages_dependencies.each_with_object([]) do |(package, dependencies), invalid_packages|
          invalid_dependencies = dependencies.filter { |path| invalid_package_path?(configuration, path) }
          invalid_packages << [package, invalid_dependencies] if invalid_dependencies.any?
        end

      if packages_with_invalid_dependencies.empty?
        Result.new(ok: true)
      else
        error_locations = packages_with_invalid_dependencies.map do |package, invalid_dependencies|
          package ||= configuration.root_path
          package_path = Pathname.new(package).relative_path_from(configuration.root_path)
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

    sig { params(configuration: Configuration).returns(Result) }
    def check_root_package_exists(configuration)
      root_package_path = File.join(configuration.root_path, "package.yml")
      all_packages_manifests = package_manifests(configuration, package_glob(configuration))

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

    sig { params(configuration: Configuration, paths: T::Array[String]).returns(T::Array[Pathname]) }
    def relative_paths(configuration, paths)
      paths.map { |path| relative_path(configuration, path) }
    end

    sig { params(configuration: Configuration, path: T.untyped).returns(T::Boolean) }
    def invalid_package_path?(configuration, path)
      # Packages at the root can be implicitly specified as "."
      return false if path == "."

      package_path = File.join(configuration.root_path, path, PackageSet::PACKAGE_CONFIG_FILENAME)
      !File.file?(package_path)
    end
  end
end
