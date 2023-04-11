# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class Command < Thor::Group
      extend T::Sig

      class << self
        extend T::Sig

        sig { returns(T::Boolean) }
        def exit_on_failure?
          false
        end

        sig { returns(String) }
        def usage
          command_name
        end

        sig { returns(String) }
        def description
          ""
        end

        sig { returns(String) }
        def command_name
          name = T.must(self.name)
          (name.split("::").last || "").underscore
        end
      end

      sig do
        params(
          args: T::Array[String],
          # local_options can either be a hash or an array:
          # https://github.com/rails/thor/blob/376e141adb594f3146c57e98151b97a20c93c484/lib/thor/base.rb#L63
          local_options: T.any(T::Hash[T.untyped, T.untyped], T::Array[String]),
          config: T::Hash[T.untyped, T.untyped],
        ).void
      end
      def initialize(args = [], local_options = {}, config = {})
        @configuration = T.let(config.fetch(:packwerk), Configuration)
        @shell = T.let(config.fetch(:shell), Shell)
        super
      end

      private

      sig { returns(Configuration) }
      attr_reader(:configuration)

      sig { returns(Shell) }
      def shell
        @shell # NOTE: Bug in Sorbet, this can't be a reader because Sorbet
              # changes method visability temporarily and Thor gets mad.
      end

      sig { params(result: Packwerk::Cli::Result).returns(T::Boolean) }
      def output_result(result)
        say
        say(result.message)
        result.status
      end

      sig do
        params(
          relative_file_paths: T::Array[String],
          ignore_nested_packages: T::Boolean
        ).returns(FilesForProcessing)
      end
      def fetch_files_to_process(relative_file_paths, ignore_nested_packages)
        files_for_processing = FilesForProcessing.fetch(
          relative_file_paths: relative_file_paths,
          ignore_nested_packages: ignore_nested_packages,
          configuration: configuration,
        )
        say(<<~MSG.squish) if files_for_processing.files.empty?
          No files found or given.
          Specify files or check the include and exclude glob in the config file.
        MSG

        files_for_processing
      end

      sig { params(args: T::Array[String]).returns(ParseRun) }
      def parse_run(args)
        relative_file_paths = T.let([], T::Array[String])
        ignore_nested_packages = T.let(false, T::Boolean)
        formatter = shell.offenses_formatter

        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            relative_file_paths = p
            ignore_nested_packages = true
          end

          parser.on("--offenses-formatter=FORMATTER", String,
            "identifier of offenses formatter to use") do |formatter_identifier|
            formatter = OffensesFormatter.find(formatter_identifier)
          end
        end.parse!(args)

        relative_file_paths = args if relative_file_paths.empty?

        files_for_processing = fetch_files_to_process(relative_file_paths, ignore_nested_packages)

        ParseRun.new(
          relative_file_set: files_for_processing.files,
          file_set_specified: files_for_processing.files_specified?,
          configuration: configuration,
          progress_formatter: shell.progress_formatter,
          offenses_formatter: formatter
        )
      end
    end
  end
end
