# typed: strict
# frozen_string_literal: true

require "rubydex"
require "prism"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  # Uses Rubydex::Graph for indexing, constant resolution, and reference extraction.
  class RunContext
    extend T::Sig

    RAILS_ASSOCIATIONS = T.let(
      [:belongs_to, :has_many, :has_one, :has_and_belongs_to_many].to_set.freeze,
      T::Set[Symbol],
    )

    class << self
      extend T::Sig

      sig do
        params(configuration: Configuration).returns(RunContext)
      end
      def from_configuration(configuration)
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: ActiveSupport::Inflector,
          custom_associations: configuration.custom_associations,
          associations_exclude: configuration.associations_exclude,
          include_globs: configuration.include,
          exclude_globs: configuration.exclude,
        )
      end
    end

    sig do
      params(
        root_path: String,
        load_paths: T::Hash[String, Module],
        inflector: T.class_of(ActiveSupport::Inflector),
        package_paths: T.nilable(T.any(T::Array[String], String)),
        custom_associations: T::Array[Symbol],
        associations_exclude: T::Array[String],
        include_globs: T::Array[String],
        exclude_globs: T::Array[String],
        checkers: T::Array[Checker],
      ).void
    end
    def initialize(
      root_path:,
      load_paths:,
      inflector:,
      package_paths: nil,
      custom_associations: [],
      associations_exclude: [],
      include_globs: Configuration::DEFAULT_INCLUDE_GLOBS,
      exclude_globs: Configuration::DEFAULT_EXCLUDE_GLOBS,
      checkers: Checker.all
    )
      @root_path = root_path
      @load_paths = load_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @associations_exclude = associations_exclude
      @checkers = checkers
      @package_paths = package_paths
      @include_globs = include_globs
      @exclude_globs = exclude_globs

      @real_root_path = T.let(File.realpath(root_path), String)
      @associations = T.let(RAILS_ASSOCIATIONS | custom_associations.to_set, T::Set[Symbol])
      @graph = T.let(Rubydex::Graph.new(workspace_path: @real_root_path), Rubydex::Graph)
      @package_set = T.let(nil, T.nilable(PackageSet))
      @reference_checker = T.let(
        ReferenceChecking::ReferenceChecker.new(@checkers),
        ReferenceChecking::ReferenceChecker,
      )
    end

    # Phase 1: Index all files into the Rubydex graph and run resolution.
    #
    # We index ALL Ruby files in the workspace (not just the files being checked)
    # so that Rubydex can resolve cross-package constant references. The checked
    # file set may be a subset (e.g. `packwerk check components/timeline`), but
    # resolution needs to see definitions across the entire codebase.
    sig { params(relative_file_set: FilesForProcessing::RelativeFileSet).void }
    def index_and_resolve(relative_file_set)
      all_rb_files = T.let([], T::Array[String])
      erb_files_to_check = T.let([], T::Array[String])

      # Collect all Ruby files in the workspace for indexing
      all_workspace_files = Dir.glob(
        @include_globs.map { |glob| File.join(@root_path, glob) }
      ) - Dir.glob(
        @exclude_globs.map { |glob| File.join(@root_path, glob) }
      )

      all_workspace_files.each do |abs_path|
        if abs_path.end_with?(".erb")
          # Only extract ERB files that are in the check set
          rel_path = abs_path.delete_prefix("#{@root_path}/")
          erb_files_to_check << abs_path if relative_file_set.include?(rel_path)
        else
          all_rb_files << abs_path
        end
      end

      # Index all Ruby files for complete resolution
      @graph.index_all(all_rb_files) unless all_rb_files.empty?

      # Index ERB files in the check set by extracting their Ruby source
      erb_parser = Parsers::Erb.new
      erb_files_to_check.each do |erb_file|
        ruby_source = erb_parser.extract_ruby_source(file_path: erb_file)
        next unless ruby_source

        @graph.index_source(erb_file, ruby_source, "ruby")
      end

      @graph.resolve
    end

    # Phase 2: Walk all resolved constant references and check for violations.
    # Groups offenses by source file and yields per-file for progress reporting.
    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
        block: T.nilable(T.proc.params(offenses: T::Array[Offense]).void),
      ).returns(T::Array[Offense])
    end
    def find_offenses(relative_file_set, &block)
      offenses_by_file = collect_constant_reference_offenses(relative_file_set)
      merge_association_offenses!(offenses_by_file, relative_file_set)

      all_offenses = T.let([], T::Array[Offense])
      relative_file_set.each do |file|
        file_offenses = offenses_by_file.fetch(file, [])
        all_offenses.concat(file_offenses)
        yield(file_offenses) if block
      end

      all_offenses
    end

    sig { returns(PackageSet) }
    def package_set
      @package_set ||= ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: @package_paths)
    end

    private

    # Iterate all resolved constant references from Rubydex, map them to packages,
    # and check for dependency violations.
    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
      ).returns(T::Hash[String, T::Array[Offense]])
    end
    def collect_constant_reference_offenses(relative_file_set)
      offenses_by_file = T.let(
        Hash.new { |h, k| h[k] = [] },
        T::Hash[String, T::Array[Offense]],
      )

      @graph.constant_references.each do |ref|
        next unless ref.is_a?(Rubydex::ResolvedConstantReference)

        source_path = make_relative(ref.location.to_file_path)
        next unless relative_file_set.include?(source_path)

        declaration = ref.declaration
        target_def = declaration.definitions.first
        next unless target_def

        target_path = make_relative(target_def.location.to_file_path)

        source_package = package_set.package_from_path(source_path)
        target_package = package_set.package_from_path(target_path)
        next if source_package == target_package

        reference = Reference.new(
          package: source_package,
          relative_path: source_path,
          constant: ConstantContext.new(declaration.name, target_path, target_package),
          source_location: Node::Location.new(ref.location.start_line, ref.location.start_column),
        )

        offenses = @reference_checker.call(reference)
        offenses_by_file[source_path]&.concat(offenses)
      end

      offenses_by_file
    end

    # Run a supplementary pass to detect cross-package references from ActiveRecord associations.
    # Rubydex doesn't understand that `has_many :orders` implies a reference to `Order`,
    # so we parse those files with Prism and resolve the implied constants via the graph.
    sig do
      params(
        offenses_by_file: T::Hash[String, T::Array[Offense]],
        relative_file_set: FilesForProcessing::RelativeFileSet,
      ).void
    end
    def merge_association_offenses!(offenses_by_file, relative_file_set)
      excluded_files = Set.new(@associations_exclude.flat_map { |glob| Dir[glob] })

      relative_file_set.each do |relative_file|
        next if relative_file.end_with?(".erb")
        next if excluded_files.include?(relative_file)

        association_refs = extract_association_references(relative_file)
        association_refs.each do |const_name, nesting, location|
          declaration = @graph.resolve_constant(const_name, nesting)
          next unless declaration

          target_def = declaration.definitions.first
          next unless target_def

          target_path = make_relative(target_def.location.to_file_path)
          source_package = package_set.package_from_path(relative_file)
          target_package = package_set.package_from_path(target_path)
          next if source_package == target_package

          reference = Reference.new(
            package: source_package,
            relative_path: relative_file,
            constant: ConstantContext.new(declaration.name, target_path, target_package),
            source_location: location,
          )

          offenses = @reference_checker.call(reference)
          offenses_by_file[relative_file]&.concat(offenses)
        end
      end
    end

    AssociationRef = T.type_alias { [String, T::Array[String], Node::Location] }

    # Parse a single file with Prism and extract constant names implied by AR associations.
    sig { params(relative_file: String).returns(T::Array[AssociationRef]) }
    def extract_association_references(relative_file)
      source = File.read(relative_file, encoding: Encoding::UTF_8)
      result = Prism.parse(source)
      return [] unless result.success?

      refs = T.let([], T::Array[AssociationRef])
      visit_for_associations(result.value, [], refs)
      refs
    end

    # Recursively walk Prism's native AST looking for association method calls.
    # Tracks module/class nesting for constant resolution context.
    sig do
      params(
        node: Prism::Node,
        nesting: T::Array[String],
        refs: T::Array[AssociationRef],
      ).void
    end
    def visit_for_associations(node, nesting, refs)
      case node
      when Prism::CallNode
        if @associations.include?(node.name)
          const_name = association_constant_name(node)
          if const_name
            location = Node::Location.new(node.location.start_line, node.location.start_column)
            refs << [const_name, nesting.dup, location]
          end
        end
      when Prism::ClassNode
        name = constant_path_string(node.constant_path)
        if name
          fqn = nesting.empty? ? name : "#{nesting.last}::#{name}"
          nesting = [fqn] + nesting
        end
      when Prism::ModuleNode
        name = constant_path_string(node.constant_path)
        if name
          fqn = nesting.empty? ? name : "#{nesting.last}::#{name}"
          nesting = [fqn] + nesting
        end
      end

      node.child_nodes.each do |child|
        next unless child

        visit_for_associations(child, nesting, refs)
      end
    end

    # Extract the implied constant name from an association call.
    # e.g. `has_many :orders` => "Order"
    # e.g. `belongs_to :author, class_name: "Person"` => "Person"
    sig { params(call_node: Prism::CallNode).returns(T.nilable(String)) }
    def association_constant_name(call_node)
      arguments = call_node.arguments&.arguments
      return unless arguments && !arguments.empty?

      first_arg = arguments.first
      return unless first_arg.is_a?(Prism::SymbolNode)

      association_name = first_arg.value
      return unless association_name

      # Check for explicit class_name: option
      keyword_hash = T.cast(arguments.find { |a| a.is_a?(Prism::KeywordHashNode) }, T.nilable(Prism::KeywordHashNode))
      if keyword_hash
        class_name_pair = keyword_hash.elements.find do |element|
          element.is_a?(Prism::AssocNode) &&
            element.key.is_a?(Prism::SymbolNode) &&
            T.unsafe(element.key).value == "class_name"
        end
        if class_name_pair.is_a?(Prism::AssocNode) && class_name_pair.value.is_a?(Prism::StringNode)
          return T.unsafe(class_name_pair.value).content
        end
      end

      @inflector.classify(association_name)
    end

    # Convert a Prism constant path node to a string name.
    # e.g. ConstantReadNode("Foo") => "Foo"
    # e.g. ConstantPathNode("Foo::Bar") => "Foo::Bar"
    sig { params(node: T.nilable(Prism::Node)).returns(T.nilable(String)) }
    def constant_path_string(node)
      case node
      when Prism::ConstantReadNode
        node.name.to_s
      when Prism::ConstantPathNode
        parent = constant_path_string(node.parent)
        child = node.full_name.to_s
        parent ? "#{parent}::#{child}" : child
      end
    end

    sig { params(path: String).returns(String) }
    def make_relative(path)
      if path.start_with?(@root_path)
        path.delete_prefix("#{@root_path}/")
      elsif path.start_with?(@real_root_path)
        path.delete_prefix("#{@real_root_path}/")
      else
        path
      end
    end
  end

  private_constant :RunContext
end
