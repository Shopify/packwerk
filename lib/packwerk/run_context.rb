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
          parallel: configuration.parallel?,
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
        parallel: T::Boolean,
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
      parallel: true,
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
      @parallel = parallel

      @real_root_path = T.let(File.realpath(root_path), String)
      @file_uri_prefix = T.let("file://#{root_path}/", String)
      @real_file_uri_prefix = T.let("file://#{@real_root_path}/", String)
      @indexed_file_set = T.let(nil, T.nilable(FilesForProcessing::RelativeFileSet))
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

        @graph.index_source("file://#{erb_file}", ruby_source, "ruby")
      end

      @graph.resolve

      # Store the file set for precomputing the file→package mapping
      @indexed_file_set = relative_file_set
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
      offenses_by_file = collect_constant_reference_offenses(relative_file_set, parallel: @parallel)
      merge_association_offenses!(offenses_by_file, relative_file_set, parallel: @parallel)

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

    # Extract constant references from Rubydex, then check for dependency violations.
    #
    # This is split into two phases:
    # 1. Extract: iterate Rubydex's resolved references and pull all needed data into
    #    plain Ruby values (source path, constant name, target path, location). This
    #    must be sequential since it crosses the Rust FFI boundary.
    # 2. Check: group extracted references by source file and check for violations
    #    in parallel across forked workers. Only plain Ruby objects cross the fork.
    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
        parallel: T::Boolean,
      ).returns(T::Hash[String, T::Array[Offense]])
    end
    def collect_constant_reference_offenses(relative_file_set, parallel: true)
      # Phase 1: Extract data from Rubydex into plain Ruby (sequential)
      refs_by_file = extract_refs_by_file(relative_file_set)

      # Phase 2: Check violations per file (parallelizable)
      check_refs_for_violations(refs_by_file, parallel: parallel)
    end

    # A plain Ruby representation of a resolved constant reference,
    # safe to pass across fork boundaries.
    ExtractedRef = T.type_alias do
      {
        const_name: String,
        target_path: String,
        line: Integer,
        column: Integer,
      }
    end

    # Pre-compute a mapping of constant name → set of packages that define it,
    # plus the canonical definition path.
    #
    # When a constant has multiple definitions (e.g. a canonical file + class reopenings),
    # we prefer the definition whose path matches Zeitwerk naming conventions for that
    # constant. For example, for `ApiClient`:
    #   - `app/models/api_client.rb` → canonical (matches Zeitwerk convention)
    #   - `app/models/api_client/extension.rb` → reopening (ignored)
    #
    # This matches the old `constant_resolver` behavior which only resolved to
    # Zeitwerk-canonical paths.
    sig { returns(T::Hash[String, { packages: T::Set[Package], target_path: T.nilable(String) }]) }
    def constant_definition_packages
      @constant_definition_packages ||= T.let(
        begin
          result = T.let(
            {},
            T::Hash[String, { packages: T::Set[Package], target_path: T.nilable(String) }],
          )

          @graph.declarations.each do |declaration|
            # Normalize metaclass names: "Foo::<Foo>" → "Foo"
            const_name = normalize_constant_name(declaration.name)

            declaration.definitions.each do |defn|
              dp = location_to_relative_path(defn.location)
              next unless dp

              entry = result[const_name] ||= { packages: Set.new, target_path: nil }
              T.unsafe(entry[:packages]) << package_for(dp)

              # Prefer the definition whose path matches Zeitwerk naming
              zeitwerk_suffix = "#{ActiveSupport::Inflector.underscore(const_name)}.rb"
              if dp.end_with?(zeitwerk_suffix)
                entry[:target_path] ||= dp
              end
              entry[:target_path] ||= dp
            end
          end

          # Remove entries with no packages (shouldn't happen, but be safe)
          result.reject! { |_, v| T.unsafe(v[:packages]).empty? }

          result
        end,
        T.nilable(T::Hash[String, { packages: T::Set[Package], target_path: T.nilable(String) }]),
      )
    end

    # Iterate all resolved constant references from Rubydex and extract the data
    # needed for violation checking into plain Ruby hashes, grouped by source file.
    #
    # Shared namespaces (e.g. `GraphApi`, `Checkouts`) are defined in many packages.
    # We pre-compute which packages define each constant so the per-reference check is O(1).
    # If the source package is in the set of packages that define the constant,
    # the reference is local and skipped.
    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
      ).returns(T::Hash[String, T::Array[ExtractedRef]])
    end
    def extract_refs_by_file(relative_file_set)
      refs_by_file = T.let(
        Hash.new { |h, k| h[k] = [] },
        T::Hash[String, T::Array[ExtractedRef]],
      )

      defn_packages = constant_definition_packages

      @graph.constant_references.each do |ref|
        next unless ref.is_a?(Rubydex::ResolvedConstantReference)

        source_path = location_to_relative_path(ref.location)
        next unless source_path
        next unless relative_file_set.include?(source_path)

        raw_name = ref.declaration.name
        const_name = normalize_constant_name(raw_name)
        info = defn_packages[const_name]
        next unless info

        source_package = package_for(source_path)

        # If ANY definition of this constant is in the source package, it's a local reference
        next if info[:packages].include?(source_package)

        target_path = info[:target_path]
        next unless target_path

        refs_by_file[source_path] << {
          const_name: "::#{const_name}",
          target_path: target_path,
          line: ref.location.start_line,
          column: ref.location.start_column,
        }
      end

      refs_by_file
    end

    # Check extracted references for dependency violations, optionally in parallel.
    sig do
      params(
        refs_by_file: T::Hash[String, T::Array[ExtractedRef]],
        parallel: T::Boolean,
      ).returns(T::Hash[String, T::Array[Offense]])
    end
    def check_refs_for_violations(refs_by_file, parallel: true)
      file_list = refs_by_file.keys

      results = if parallel
        Parallel.map(file_list) do |source_path|
          [source_path, check_file_refs(source_path, T.must(refs_by_file[source_path]))]
        end
      else
        file_list.map do |source_path|
          [source_path, check_file_refs(source_path, T.must(refs_by_file[source_path]))]
        end
      end

      offenses_by_file = T.let(
        Hash.new { |h, k| h[k] = [] },
        T::Hash[String, T::Array[Offense]],
      )
      results.each do |source_path, offenses|
        offenses_by_file[source_path] = offenses if offenses.any?
      end
      offenses_by_file
    end

    # Check a single file's extracted references for violations.
    sig do
      params(
        source_path: String,
        refs: T::Array[ExtractedRef],
      ).returns(T::Array[Offense])
    end
    def check_file_refs(source_path, refs)
      source_package = package_for(source_path)
      offenses = T.let([], T::Array[Offense])

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
    sig do
      params(
        offenses_by_file: T::Hash[String, T::Array[Offense]],
        relative_file_set: FilesForProcessing::RelativeFileSet,
        parallel: T::Boolean,
      ).void
    end
    def merge_association_offenses!(offenses_by_file, relative_file_set, parallel: true)
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

      # Parse targeted files and extract association references
      all_association_refs = if parallel
        Parallel.flat_map(files_to_scan) do |relative_file|
          extract_association_references(relative_file).map do |const_name, nesting, location|
            [relative_file, const_name, nesting, location]
          end
        end
      else
        files_to_scan.flat_map do |relative_file|
          extract_association_references(relative_file).map do |const_name, nesting, location|
            [relative_file, const_name, nesting, location]
          end
        end
      end

      # Phase 2: Resolve and check violations (must be sequential -- uses shared graph + package_set)
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

    # Normalize a Rubydex declaration name to a plain Ruby constant name.
    # Rubydex uses `Foo::<Foo>` for the singleton/metaclass of `Foo` (from `class << self`),
    # and `Foo::<Foo>#method` for singleton methods. Strip these internal suffixes so that
    # the constant name matches what appears in package_todo.yml and Ruby source.
    sig { params(name: String).returns(String) }
    def normalize_constant_name(name)
      # Strip singleton class suffix: "Foo::<Foo>" → "Foo"
      # Strip method suffixes: "Foo::<Foo>#bar()" → "Foo"
      name.sub(/::<[^>]+>.*\z/, "")
    end

    # Convert a Rubydex::Location to a relative file path using the fast URI accessor.
    # `location.uri` returns a raw string (no URI parsing), which is ~5x faster than
    # `location.to_file_path` on large codebases (11s vs 57s for 2.7M calls on Core).
    # Returns nil if the location doesn't use a file:// URI.
    sig { params(location: Rubydex::Location).returns(T.nilable(String)) }
    def location_to_relative_path(location)
      uri = location.uri
      if uri.start_with?(@file_uri_prefix)
        uri.delete_prefix(@file_uri_prefix)
      elsif uri.start_with?(@real_file_uri_prefix)
        uri.delete_prefix(@real_file_uri_prefix)
      end
    end

    # Precomputed file→package mapping to avoid repeated path prefix searches.
    sig { returns(T::Hash[String, Package]) }
    def file_to_package_map
      @file_to_package_map ||= T.let(
        begin
          map = T.let({}, T::Hash[String, Package])
          @indexed_file_set&.each { |f| map[f] = package_set.package_from_path(f) }
          map
        end,
        T.nilable(T::Hash[String, Package]),
      )
    end

    # Fast package lookup using precomputed map, falling back to PackageSet for unknown paths.
    sig { params(relative_path: String).returns(Package) }
    def package_for(relative_path)
      file_to_package_map[relative_path] || package_set.package_from_path(relative_path)
    end
  end

  private_constant :RunContext
end
