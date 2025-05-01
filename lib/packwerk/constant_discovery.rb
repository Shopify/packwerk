# typed: strict
# frozen_string_literal: true

module Packwerk
  # Determines context for constants based on the provided `Zeitwerk::Loaders` such as
  # their file location and the package they belong to.
  class ConstantDiscovery
    extend T::Sig

    class Error < StandardError; end

    sig do
      params(
        packages:  PackageSet,
        root_path: String,
        loaders:   T::Enumerable[Zeitwerk::Loader]
      ).void
    end
    def initialize(packages, root_path:, loaders:)
      @packages = packages
      @root_path = root_path
      @loaders = loaders
    end

    # Get the package that owns a given file path.
    #
    # @param path [String] the file path
    #
    # @return [Packwerk::Package] the package that contains the given file,
    #   or nil if the path is not owned by any component
    sig do
      params(
        path: String,
      ).returns(Packwerk::Package)
    end
    def package_from_path(path)
      @packages.package_from_path(path)
    end

    # Analyze a constant via its name.
    # If the constant is unresolved, we need the current namespace path to correctly infer its full name
    #
    # @param const_name [String] The unresolved constant's name.
    # @param current_namespace_path [Array<String>] (optional) The namespace of the context in which the constant is
    #   used, e.g. ["Apps", "Models"] for `Apps::Models`. Defaults to [] which means top level.
    # @return [ConstantContext]
    sig do
      params(
        const_name: String,
        current_namespace_path: T.nilable(T::Array[String]),
      ).returns(T.nilable(ConstantContext))
    end
    def context_for(const_name, current_namespace_path: [])
      current_namespace_path = [] if const_name.start_with?("::")
      const_name, location = resolve_constant(const_name.delete_prefix("::"), current_namespace_path)

      return unless location

      location = location.delete_prefix("#{@root_path}#{File::SEPARATOR}").to_s
      ConstantContext.new(const_name, location, package_from_path(location))
    end

    # Analyze the constants and raise errors if any potential issues are encountered that would prevent
    # resolving the context for constants, such as ambiguous constant locations.
    #
    # @return [ConstantDiscovery]
    sig { returns(ConstantDiscovery) }
    def validate_constants
      tap { const_locations }
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class.name}>"
    end

    private

    sig { returns(T::Hash[String, String]) }
    def const_locations
      return @const_locations unless @const_locations.nil?

      all_cpaths = @loaders.inject({}) do |cpaths, loader|
        paths = loader.all_expected_cpaths.filter do |cpath, _const|
          cpath.ends_with?(".rb")
        end
        cpaths.merge(paths)
      end

      paths_by_const = all_cpaths.invert
      validate_constant_paths(paths_by_const, all_cpaths: all_cpaths)
      @const_locations = paths_by_const
    end

    sig do
      params(
        const_name:             String,
        current_namespace_path: T.nilable(T::Array[String]),
        original_name:          String
      ).returns(T::Array[T.nilable(String)])
    end
    def resolve_constant(const_name, current_namespace_path, original_name: const_name)
      namespace, location = resolve_traversing_namespace_path(const_name, current_namespace_path)
      if location
        ["::" + namespace.push(original_name).join("::"), location]
      elsif !const_name.include?("::")
        # constant could not be resolved to a file in the given load paths
        [nil, nil]
      else
        parent_constant = const_name.split("::")[0..-2].join("::")
        resolve_constant(parent_constant, current_namespace_path, original_name: original_name)
      end
    end

    sig do
      params(
        const_name:             String,
        current_namespace_path: T.nilable(T::Array[String]),
      ).returns(T::Array[T.nilable(String)])
    end
    def resolve_traversing_namespace_path(const_name, current_namespace_path)
      fully_qualified_name_guess = (current_namespace_path + [const_name]).join("::")

      location = const_locations[fully_qualified_name_guess]
      if location || fully_qualified_name_guess == const_name
        [current_namespace_path, location]
      else
        resolve_traversing_namespace_path(const_name, current_namespace_path[0..-2])
      end
    end

    sig do
      params(
        paths_by_constant: T::Hash[String, String],
        all_cpaths:        T::Hash[String, String]
      ).void
    end
    def validate_constant_paths(paths_by_constant, all_cpaths:)
      raise(Error, "Could not find any ruby files.") if all_cpaths.empty?

      is_ambiguous = all_cpaths.size != paths_by_constant.size
      raise(Error, ambiguous_constants_hint(paths_by_constant, all_cpaths: all_cpaths)) if is_ambiguous
    end

    sig do
      params(
        paths_by_constant: T::Hash[String, String],
        all_cpaths:        T::Hash[String, String]
      ).returns(String)
    end
    def ambiguous_constants_hint(paths_by_constant, all_cpaths:)
      ambiguous_constants = all_cpaths.except(*paths_by_constant.invert.keys).values
      <<~MSG
        Ambiguous constant definition:
        #{ambiguous_constants.map { |const| " - #{const}" }.join("\n")}
      MSG
    end
  end

  private_constant :ConstantDiscovery
end
