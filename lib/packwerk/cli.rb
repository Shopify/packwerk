# typed: strict
# frozen_string_literal: true

module Packwerk
  # A command-line interface to Packwerk.
  class Cli
    extend T::Sig
    extend ActiveSupport::Autoload

    autoload :BaseCommand
    autoload :Result
    autoload :UsesParseRun

    @commands_registry = T.let({}, T::Hash[String, T.class_of(BaseCommand)])

    class << self
      extend T::Sig

      sig { params(command_class: T.class_of(BaseCommand), names: T::Array[String]).void }
      def register_command(command_class, names)
        names.each do |name|
          @commands_registry[name] = command_class
        end
      end

      sig { params(command: String).returns(T.nilable(T.class_of(BaseCommand))) }
      def command_class_for(command)
        @commands_registry[command]
      end
    end

    sig do
      params(
        configuration: T.nilable(Configuration),
        out: T.any(StringIO, IO),
        err_out: T.any(StringIO, IO),
        environment: String,
        style: OutputStyle,
        offenses_formatter: T.nilable(OffensesFormatter)
      ).void
    end
    def initialize(
      configuration: nil,
      out: $stdout,
      err_out: $stderr,
      environment: "test",
      style: OutputStyles::Plain.new,
      offenses_formatter: nil
    )
      @out = out
      @err_out = err_out
      @environment = environment
      @style = style
      @configuration = T.let(configuration || Configuration.from_path, Configuration)
      @progress_formatter = T.let(Formatters::ProgressFormatter.new(@out, style: style), Formatters::ProgressFormatter)
      @offenses_formatter = T.let(
        offenses_formatter || @configuration.offenses_formatter,
        OffensesFormatter
      )
    end

    sig { returns(Configuration) }
    attr_reader :configuration

    sig { returns(OffensesFormatter) }
    attr_reader :offenses_formatter

    sig { returns(Formatters::ProgressFormatter) }
    attr_reader :progress_formatter

    sig { returns(T.any(IO, StringIO)) }
    attr_reader :out

    sig { params(args: T::Array[String]).returns(T.noreturn) }
    def run(args)
      success = execute_command(args)
      exit(success)
    end

    sig { params(args: T::Array[String]).returns(T::Boolean) }
    def execute_command(args)
      command = args.shift || "help"
      command_class = self.class.command_class_for(command)

      result = if command_class
        command_class.new(self, args).run
      else
        Result.new(
          status: false,
          message: "'#{command}' is not a packwerk command. See `packwerk help`.",
          print_as_error: true
        )
      end

      if result.print_as_error
        @err_out.puts(result.message)
      else
        @out.puts(result.message)
      end
      result.status
    end
  end
end

Dir[File.join(__dir__, "cli", "*_command.rb")].each { |file| require file }
