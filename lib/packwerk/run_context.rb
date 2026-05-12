# typed: strict
# frozen_string_literal: true

require "rubydex"
require "prism"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  # Uses Rubydex::Graph for indexing, constant resolution, and reference extraction.
  class RunContext
    RAILS_ASSOCIATIONS = [:belongs_to, :has_many, :has_one, :has_and_belongs_to_many].to_set.freeze #: Set[Symbol]

    # A plain Ruby representation of a resolved constant reference.
    #: type extracted_ref = { const_name: String, target_path: String, line: Integer, column: Integer }

    #: type association_ref = [String, Array[String], Node::Location]

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
      @file_uri_prefix = "file://#{root_path}/" #: String
      @real_file_uri_prefix = "file://#{@real_root_path}/" #: String
      @indexed_file_set = nil #: FilesForProcessing::relative_file_set?
      @associations = (RAILS_ASSOCIATIONS | custom_associations.to_set) #: Set[Symbol]
      @graph = Rubydex::Graph.new(workspace_path: @real_root_path) #: Rubydex::Graph
      @package_set = nil #: PackageSet?
      @reference_checker = ReferenceChecking::ReferenceChecker.new(@checkers) #: ReferenceChecking::ReferenceChecker
      @file_to_package_map = nil #: Hash[String, Package]?
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

      @indexed_file_set = all_files
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

    # Extract constant references from Rubydex, then check for dependency violations.
    #
    # This is split into two phases:
    # 1. Extract: iterate Rubydex's resolved references and pull all needed data into
    #    plain Ruby values (source path, constant name, target path, location). This
    #    crosses the Rust FFI boundary and must be sequential.
    # 2. Check: walk extracted references per file and check for violations.
    #: (FilesForProcessing::relative_file_set relative_file_set) -> Hash[String, Array[Offense]]
    def collect_constant_reference_offenses(relative_file_set)
      refs_by_file = extract_refs_by_file(relative_file_set)
      check_refs_for_violations(refs_by_file)
    end

    # Iterate declarations and their references to extract cross-package violations.
    #
    # Iterates per-declaration rather than per-reference because:
    # - Many declarations have zero references in the workspace (skip them entirely)
    # - Per-declaration work (resolving canonical name, package set, Zeitwerk path)
    #   is computed once per constant rather than once per reference
    # - Uses Declaration#references (added in Rubydex 0.2) which gives the references
    #   TO each declaration, avoiding the global reference iteration
    #
    # Shared namespaces (e.g. `GraphApi`, `Checkouts`) are defined in many packages.
    # If the source package is in the set of packages that define the constant,
    # the reference is local and skipped.
    #: (FilesForProcessing::relative_file_set relative_file_set) -> Hash[String, Array[extracted_ref]]
    def extract_refs_by_file(relative_file_set)
      refs_by_file = Hash.new { |h, k| h[k] = [] } #: Hash[String, Array[extracted_ref]]

      # Cache package lookups per file to avoid repeated hash lookups
      file_package_cache = {} #: Hash[String, Package]
      real_prefix = @real_file_uri_prefix
      file_prefix = @file_uri_prefix

      @graph.declarations.each do |declaration|
        # Skip singleton classes (Foo::<Foo>) -- their references duplicate the regular
        # class's references (Foo.bar produces refs to BOTH Foo and Foo::<Foo>).
        next if declaration.is_a?(Rubydex::SingletonClass)

        const_name = declaration.name

        # Compute the set of packages that define this constant + the canonical target path.
        # Done lazily inside the loop because we only do this work for declarations
        # that actually have references (saves time for unreferenced constants).
        defn_packages = nil #: Set[Package]?
        target_path = nil #: String?
        zeitwerk_suffix = nil #: String?

        declaration.references.each do |ref|
          next unless ref.is_a?(Rubydex::ResolvedConstantReference)

          # Inline URI → relative path conversion for speed (avoids method call overhead on hot path)
          loc = ref.location
          uri = loc.uri
          source_path = if uri.start_with?(real_prefix)
            uri.byteslice(real_prefix.bytesize..)
          elsif uri.start_with?(file_prefix)
            uri.byteslice(file_prefix.bytesize..)
          end
          next unless source_path
          next unless relative_file_set.include?(source_path)

          # Lazily compute defn_packages and target_path (only if we have at least one in-set ref)
          if defn_packages.nil?
            defn_packages = Set.new
            zeitwerk_suffix = "#{ActiveSupport::Inflector.underscore(const_name)}.rb"
            declaration.definitions.each do |defn|
              defn_uri = defn.location.uri
              dp = if defn_uri.start_with?(real_prefix)
                defn_uri.byteslice(real_prefix.bytesize..)
              elsif defn_uri.start_with?(file_prefix)
                defn_uri.byteslice(file_prefix.bytesize..)
              end
              next unless dp

              defn_packages << package_for(dp)
              # Prefer the definition whose path matches Zeitwerk naming
              if dp.end_with?(zeitwerk_suffix)
                target_path ||= dp
              end
              target_path ||= dp
            end
          end

          next if defn_packages.empty?
          next unless target_path

          source_package = file_package_cache[source_path] ||= package_for(source_path)

          # If ANY definition of this constant is in the source package, it's a local reference
          next if defn_packages.include?(source_package)

          bucket = refs_by_file[source_path] #: as !nil
          bucket << {
            const_name: "::#{const_name}",
            target_path: target_path,
            line: loc.start_line,
            column: loc.start_column,
          }
        end
      end

      refs_by_file
    end

    # Check extracted references for dependency violations.
    #: (Hash[String, Array[extracted_ref]] refs_by_file) -> Hash[String, Array[Offense]]
    def check_refs_for_violations(refs_by_file)
      offenses_by_file = Hash.new { |h, k| h[k] = [] } #: Hash[String, Array[Offense]]

      refs_by_file.each do |source_path, refs|
        offenses = check_file_refs(source_path, refs)
        offenses_by_file[source_path] = offenses if offenses.any?
      end

      offenses_by_file
    end

    # Check a single file's extracted references for violations.
    #: (String source_path, Array[extracted_ref] refs) -> Array[Offense]
    def check_file_refs(source_path, refs)
      source_package = package_for(source_path)
      offenses = [] #: Array[Offense]

      refs.each do |ref|
        target_package = package_for(ref[:target_path])
        next if source_package == target_package

        reference = Reference.new(
          package: source_package,
          relative_path: source_path,
          constant: ConstantContext.new(ref[:const_name], ref[:target_path], target_package),
          source_location: Node::Location.new(ref[:line], ref[:column]),
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
        extract_association_references(relative_file).map do |const_name, nesting, location|
          [relative_file, const_name, nesting, location]
        end
      end

      # Resolve and check violations (uses shared graph + package_set)
      all_association_refs.each do |relative_file, const_name, nesting, location|
        declaration = @graph.resolve_constant(const_name, nesting)
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
          source_location: location,
        )

        offenses = @reference_checker.call(reference)
        offenses_by_file[relative_file]&.concat(offenses)
      end
    end

    # Parse a single file with Prism and extract constant names implied by AR associations.
    #: (String relative_file) -> Array[association_ref]
    def extract_association_references(relative_file)
      source = File.read(relative_file, encoding: Encoding::UTF_8)
      result = Prism.parse(source)
      return [] unless result.success?

      refs = [] #: Array[association_ref]
      visit_for_associations(result.value, [], refs)
      refs
    end

    # Recursively walk Prism's native AST looking for association method calls.
    # Tracks module/class nesting for constant resolution context.
    #: (Prism::Node node, Array[String] nesting, Array[association_ref] refs) -> void
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

    # Convert a Rubydex::Location to a relative file path using the fast URI accessor.
    # `location.uri` returns a raw string (no URI parsing), which is ~5x faster than
    # `location.to_file_path` on large codebases (11s vs 57s for 2.7M calls on Core).
    # Returns nil if the location doesn't use a file:// URI.
    #: (Rubydex::Location location) -> String?
    def location_to_relative_path(location)
      uri = location.uri
      if uri.start_with?(@file_uri_prefix)
        uri.delete_prefix(@file_uri_prefix)
      elsif uri.start_with?(@real_file_uri_prefix)
        uri.delete_prefix(@real_file_uri_prefix)
      end
    end

    # Precomputed file→package mapping to avoid repeated path prefix searches.
    #: -> Hash[String, Package]
    def file_to_package_map
      @file_to_package_map ||= begin
        map = {} #: Hash[String, Package]
        @indexed_file_set&.each { |f| map[f] = package_set.package_from_path(f) }
        map
      end
    end

    # Fast package lookup using precomputed map, falling back to PackageSet for unknown paths.
    #: (String relative_path) -> Package
    def package_for(relative_path)
      file_to_package_map[relative_path] || package_set.package_from_path(relative_path)
    end
  end

  private_constant :RunContext
end
