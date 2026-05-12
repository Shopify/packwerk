# typed: strict
# frozen_string_literal: true

require "rubydex"
require "prism"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  # Uses Rubydex::Graph for indexing, constant resolution, and reference extraction.
  class RunContext
    RAILS_ASSOCIATIONS = [:belongs_to, :has_many, :has_one, :has_and_belongs_to_many].to_set.freeze #: Set[Symbol]

    # A constant reference implied by a Rails-style association call (e.g.
    # `belongs_to :foo` implies a reference to `Foo`). Discovered by parsing
    # the source file with Prism rather than from the Rubydex graph.
    class AssociationReference
      #: String
      attr_reader :const_name

      # Module/class nesting in which the association call appears, used as
      # the resolution scope for `const_name`.
      #: Array[String]
      attr_reader :nesting

      #: Node::Location
      attr_reader :location

      #: (const_name: String, nesting: Array[String], location: Node::Location) -> void
      def initialize(const_name:, nesting:, location:)
        @const_name = const_name
        @nesting = nesting
        @location = location
      end
    end

    # A resolved cross-package constant reference, captured as a plain Ruby object
    # (no Rubydex types) so it can be processed in the violation-checking phase
    # independently of the Rubydex graph.
    class ExtractedRef
      #: String
      attr_reader :const_name

      #: String
      attr_reader :target_path

      #: Integer
      attr_reader :line

      #: Integer
      attr_reader :column

      #: (const_name: String, target_path: String, line: Integer, column: Integer) -> void
      def initialize(const_name:, target_path:, line:, column:)
        @const_name = const_name
        @target_path = target_path
        @line = line
        @column = column
      end
    end

    # Where a constant is defined: the set of packages containing any definition,
    # and the canonical target URI (preferring Zeitwerk-conventional paths).
    class DefinitionSet
      #: Set[Package]
      attr_reader :packages

      #: String?
      attr_reader :target_uri

      #: (Set[Package] packages, String? target_uri) -> void
      def initialize(packages, target_uri)
        @packages = packages
        @target_uri = target_uri
      end
    end

    class << self
      #: (Configuration configuration) -> RunContext
      def from_configuration(configuration)
        new(
          root_path: configuration.root_path,
          package_paths: configuration.package_paths,
          inflector: ActiveSupport::Inflector,
          custom_associations: configuration.custom_associations,
          associations_exclude: configuration.associations_exclude,
          include_globs: configuration.include,
          exclude_globs: configuration.exclude,
        )
      end
    end

    #: (
    #|   root_path: String,
    #|   inflector: singleton(ActiveSupport::Inflector),
    #|   ?package_paths: (Array[String] | String)?,
    #|   ?custom_associations: Array[Symbol],
    #|   ?associations_exclude: Array[String],
    #|   ?include_globs: Array[String],
    #|   ?exclude_globs: Array[String],
    #|   ?checkers: Array[Checker]
    #| ) -> void
    def initialize(
      root_path:,
      inflector:,
      package_paths: nil,
      custom_associations: [],
      associations_exclude: [],
      include_globs: Configuration::DEFAULT_INCLUDE_GLOBS,
      exclude_globs: Configuration::DEFAULT_EXCLUDE_GLOBS,
      checkers: Checker.all
    )
      @root_path = root_path
      @inflector = inflector
      @custom_associations = custom_associations
      @associations_exclude = associations_exclude
      @checkers = checkers
      @package_paths = package_paths
      @include_globs = include_globs
      @exclude_globs = exclude_globs
      @real_root_path = File.realpath(root_path) #: String
      @real_file_uri_prefix = "file://#{@real_root_path}/" #: String
      @associations = (RAILS_ASSOCIATIONS | custom_associations.to_set) #: Set[Symbol]
      @graph = Rubydex::Graph.new(workspace_path: @real_root_path) #: Rubydex::Graph
      @package_set = nil #: PackageSet?
      @reference_checker = ReferenceChecking::ReferenceChecker.new(@checkers) #: ReferenceChecking::ReferenceChecker

      # Maps keyed by absolute file:// URI for fast lookup in the hot reference loop
      # without re-parsing URIs. Built in index_and_resolve.
      @checked_uris = Set.new #: Set[String]
      @uri_to_package = {} #: Hash[String, Package]
      @uri_to_relative_path = {} #: Hash[String, String]
      @path_to_package = {} #: Hash[String, Package]
    end

    # Phase 1: Index all files into the Rubydex graph and run resolution.
    #
    # We index ALL Ruby files in the workspace (not just the files being checked)
    # so that Rubydex can resolve cross-package constant references. The checked
    # file set may be a subset (e.g. `packwerk check components/timeline`), but
    # resolution needs to see definitions across the entire codebase.
    #: (FilesForProcessing::relative_file_set relative_file_set, ?all_files: FilesForProcessing::relative_file_set) -> void
    def index_and_resolve(relative_file_set, all_files: relative_file_set)
      rb_files = [] #: Array[String]
      erb_files = [] #: Array[String]

      all_files.each do |rel_path|
        abs_path = File.join(@real_root_path, rel_path)
        if rel_path.end_with?(".erb")
          # Only index ERB files that are in the check set
          erb_files << abs_path if relative_file_set.include?(rel_path)
        else
          rb_files << abs_path
        end
      end

      @graph.index_all(rb_files) unless rb_files.empty?

      erb_parser = Parsers::Erb.new
      erb_files.each do |erb_file|
        ruby_source = erb_parser.extract_ruby_source(file_path: erb_file)
        next unless ruby_source

        @graph.index_source("file://#{erb_file}", ruby_source, "ruby")
      end

      @graph.resolve

      build_uri_indexes(relative_file_set, all_files)
    end

    # Phase 2: Walk all resolved constant references and check for violations.
    # Groups offenses by source file and yields per-file for progress reporting.
    #: (FilesForProcessing::relative_file_set relative_file_set) ?{ (Array[Offense] offenses) -> void } -> Array[Offense]
    def find_offenses(relative_file_set, &block)
      offenses_by_file = collect_constant_reference_offenses(relative_file_set)
      merge_association_offenses!(offenses_by_file, relative_file_set)

      all_offenses = [] #: Array[Offense]
      relative_file_set.each do |file|
        file_offenses = offenses_by_file.fetch(file, [])
        all_offenses.concat(file_offenses)
        yield(file_offenses) if block
      end

      all_offenses
    end

    #: -> PackageSet
    def package_set
      @package_set ||= ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: @package_paths)
    end

    private

    # Build URI-keyed lookup tables so the hot reference loop can compare URIs as opaque
    # strings without parsing them. Computed once per run after indexing completes.
    #
    # @checked_uris        : URIs of files we should report violations for
    # @uri_to_package      : URI -> owning Package (for all indexed workspace files)
    # @uri_to_relative_path: URI -> workspace-relative path (used when emitting offenses)
    #: (FilesForProcessing::relative_file_set relative_file_set, FilesForProcessing::relative_file_set all_files) -> void
    def build_uri_indexes(relative_file_set, all_files)
      @checked_uris = Set.new
      @uri_to_package = {}
      @uri_to_relative_path = {}

      all_files.each do |rel_path|
        uri = "#{@real_file_uri_prefix}#{rel_path}"
        package = package_set.package_from_path(rel_path)
        @uri_to_relative_path[uri] = rel_path
        @uri_to_package[uri] = package
        @path_to_package[rel_path] = package
        @checked_uris << uri if relative_file_set.include?(rel_path)
      end
    end

    # Extract constant references from Rubydex, then check for dependency violations.
    #: (FilesForProcessing::relative_file_set relative_file_set) -> Hash[String, Array[Offense]]
    def collect_constant_reference_offenses(relative_file_set)
      refs_by_file = extract_refs_by_file
      check_refs_for_violations(refs_by_file)
    end

    # Iterate declarations and their references to extract cross-package violations.
    #
    # Hot loop works entirely with absolute URIs as opaque strings: no URI parsing,
    # no path manipulation. URIs are converted to relative paths only when emitting
    # the final ExtractedRef objects (one conversion per output reference).
    #
    # Iterates per-declaration rather than per-reference because:
    # - Many declarations have zero references in the workspace (skip them entirely)
    # - Per-declaration work (resolving package set, Zeitwerk path) is computed
    #   once per constant rather than once per reference
    #: -> Hash[String, Array[ExtractedRef]]
    def extract_refs_by_file
      refs_by_file = Hash.new { |h, k| h[k] = [] } #: Hash[String, Array[ExtractedRef]]

      @graph.declarations.each do |declaration|
        # Skip singleton classes (Foo::<Foo>) -- their references duplicate the regular
        # class's references (Foo.bar produces refs to BOTH Foo and Foo::<Foo>).
        next if declaration.is_a?(Rubydex::SingletonClass)

        checked_refs = checked_references(declaration)
        next if checked_refs.empty?

        defns = definition_set_for(declaration)
        target_uri = defns.target_uri
        next if defns.packages.empty? || target_uri.nil?

        target_path = @uri_to_relative_path.fetch(target_uri)
        const_name = "::#{declaration.name}"

        checked_refs.each do |loc|
          source_uri = loc.uri
          source_package = @uri_to_package.fetch(source_uri)
          # If ANY definition of this constant is in the source package, it's a local reference
          next if defns.packages.include?(source_package)

          source_path = @uri_to_relative_path.fetch(source_uri)
          bucket = refs_by_file[source_path] #: as !nil

          # Rubydex locations use 0-based line/column; Packwerk uses 1-based for display.
          bucket << ExtractedRef.new(
            const_name: const_name,
            target_path: target_path,
            line: loc.start_line + 1,
            column: loc.start_column + 1,
          )
        end
      end

      refs_by_file
    end

    # Collect locations of references to this declaration whose source URI
    # belongs to the set of files being checked.
    #: (Rubydex::Declaration declaration) -> Array[Rubydex::Location]
    def checked_references(declaration)
      declaration.references.filter_map do |ref|
        next unless ref.is_a?(Rubydex::ResolvedConstantReference)

        loc = ref.location
        loc if @checked_uris.include?(loc.uri)
      end
    end

    # Summarize where a constant is defined: the set of packages containing any
    # definition, and the canonical target URI (preferring Zeitwerk-conventional paths
    # like `ApiClient` → `app/models/api_client.rb`).
    #: (Rubydex::Declaration declaration) -> DefinitionSet
    def definition_set_for(declaration)
      defined_uris = declaration.definitions.filter_map do |defn|
        uri = defn.location.uri
        uri if @uri_to_package.key?(uri)
      end

      packages = defined_uris.map { |uri| @uri_to_package.fetch(uri) }.to_set
      zeitwerk_suffix = "#{ActiveSupport::Inflector.underscore(declaration.name)}.rb"
      target_uri = defined_uris.find { |uri| uri.end_with?(zeitwerk_suffix) } || defined_uris.first

      DefinitionSet.new(packages, target_uri)
    end

    # Check extracted references for dependency violations.
    #: (Hash[String, Array[ExtractedRef]] refs_by_file) -> Hash[String, Array[Offense]]
    def check_refs_for_violations(refs_by_file)
      offenses_by_file = Hash.new { |h, k| h[k] = [] } #: Hash[String, Array[Offense]]

      refs_by_file.each do |source_path, refs|
        offenses = check_file_refs(source_path, refs)
        offenses_by_file[source_path] = offenses if offenses.any?
      end

      offenses_by_file
    end

    # Check a single file's extracted references for violations.
    #: (String source_path, Array[ExtractedRef] refs) -> Array[Offense]
    def check_file_refs(source_path, refs)
      source_package = package_for(source_path)
      offenses = [] #: Array[Offense]

      refs.each do |ref|
        target_package = package_for(ref.target_path)
        # Already filtered by definition_set_for, but keep for safety
        next if source_package == target_package

        reference = Reference.new(
          package: source_package,
          relative_path: source_path,
          constant: ConstantContext.new(ref.const_name, ref.target_path, target_package),
          source_location: Node::Location.new(ref.line, ref.column),
        )

        offenses.concat(@reference_checker.call(reference))
      end

      offenses
    end

    # Run a supplementary pass to detect cross-package references from ActiveRecord associations.
    # Rubydex doesn't understand that `has_many :orders` implies a reference to `Order`,
    # so we parse those files with Prism and resolve the implied constants via the graph.
    #
    # Uses graph.method_references to identify which files contain association calls,
    # then only parses those files with Prism (typically ~1% of all files).
    #: (Hash[String, Array[Offense]] offenses_by_file, FilesForProcessing::relative_file_set relative_file_set) -> void
    def merge_association_offenses!(offenses_by_file, relative_file_set)
      excluded_files = Set.new(@associations_exclude.flat_map { |glob| Dir[glob] })

      # Use Rubydex's method references to find only files that contain association calls.
      # This avoids reparsing all 57k+ files when only ~1.3% have associations.
      association_names = @associations.map(&:to_s).to_set
      files_with_associations = Set.new
      @graph.method_references.each do |ref|
        next unless association_names.include?(ref.name)

        rel_path = location_to_relative_path(ref.location)
        next unless rel_path

        files_with_associations << rel_path
      end

      files_to_scan = files_with_associations & relative_file_set - excluded_files

      all_association_refs = files_to_scan.flat_map do |relative_file|
        extract_association_references(relative_file).map { |assoc_ref| [relative_file, assoc_ref] }
      end

      # Resolve and check violations (uses shared graph + package_set)
      all_association_refs.each do |relative_file, assoc_ref|
        declaration = @graph.resolve_constant(assoc_ref.const_name, assoc_ref.nesting)
        next unless declaration

        target_def = declaration.definitions.first
        next unless target_def

        target_path = location_to_relative_path(target_def.location)
        next unless target_path

        source_package = package_for(relative_file)
        target_package = package_for(target_path)
        next if source_package == target_package

        reference = Reference.new(
          package: source_package,
          relative_path: relative_file,
          constant: ConstantContext.new("::#{declaration.name}", target_path, target_package),
          source_location: assoc_ref.location,
        )

        offenses = @reference_checker.call(reference)
        offenses_by_file[relative_file]&.concat(offenses)
      end
    end

    # Parse a single file with Prism and extract constant names implied by AR associations.
    #: (String relative_file) -> Array[AssociationReference]
    def extract_association_references(relative_file)
      source = File.read(relative_file, encoding: Encoding::UTF_8)
      result = Prism.parse(source)
      return [] unless result.success?

      refs = [] #: Array[AssociationReference]
      visit_for_associations(result.value, [], refs)
      refs
    end

    # Recursively walk Prism's native AST looking for association method calls.
    # Tracks module/class nesting for constant resolution context.
    #: (Prism::Node node, Array[String] nesting, Array[AssociationReference] refs) -> void
    def visit_for_associations(node, nesting, refs)
      case node
      when Prism::CallNode
        if @associations.include?(node.name)
          const_name = association_constant_name(node)
          if const_name
            # Prism uses 1-based line, 0-based column; Packwerk uses 1-based for both.
            location = Node::Location.new(node.location.start_line, node.location.start_column + 1)
            refs << AssociationReference.new(const_name: const_name, nesting: nesting.dup, location: location)
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
    #: (Prism::CallNode call_node) -> String?
    def association_constant_name(call_node)
      arguments = call_node.arguments&.arguments
      return unless arguments && !arguments.empty?

      first_arg = arguments.first
      return unless first_arg.is_a?(Prism::SymbolNode)

      association_name = first_arg.value
      return unless association_name

      # Check for explicit class_name: option
      keyword_hash = arguments.find { |a| a.is_a?(Prism::KeywordHashNode) }
      if keyword_hash.is_a?(Prism::KeywordHashNode)
        class_name_pair = keyword_hash.elements.find do |element|
          next false unless element.is_a?(Prism::AssocNode)

          key = element.key
          key.is_a?(Prism::SymbolNode) && key.value == "class_name"
        end
        if class_name_pair.is_a?(Prism::AssocNode)
          value = class_name_pair.value
          return value.content if value.is_a?(Prism::StringNode)
        end
      end

      @inflector.classify(association_name)
    end

    # Convert a Prism constant path node to a string name.
    # e.g. ConstantReadNode("Foo") => "Foo"
    # e.g. ConstantPathNode("Foo::Bar") => "Foo::Bar"
    #: (Prism::Node? node) -> String?
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

    # Look up the workspace-relative path for a Rubydex::Location.
    # Returns nil for locations outside the indexed workspace (e.g. rubydex:built-in).
    #: (Rubydex::Location location) -> String?
    def location_to_relative_path(location)
      @uri_to_relative_path[location.uri]
    end

    # Look up a package by relative file path, using the precomputed map and
    # falling back to PackageSet for unknown paths (e.g. files not in the index).
    #: (String relative_path) -> Package
    def package_for(relative_path)
      @path_to_package[relative_path] || package_set.package_from_path(relative_path)
    end
  end

  private_constant :RunContext
end
