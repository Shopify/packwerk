# typed: strict
# frozen_string_literal: true

module Packwerk
  # A command-line interface to Packwerk.
  class Cli
    extend T::Sig

    #: (
    #|   ?configuration: Configuration?,
    #|   ?out: (StringIO | IO),
    #|   ?err_out: (StringIO | IO),
    #|   ?environment: String,
    #|   ?style: OutputStyle,
    #|   ?offenses_formatter: OffensesFormatter?
    #| ) -> void
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

    #: (Array[String] args) -> bot
    def run(args)
      success = execute_command(args)
      exit(success)
    end

    #: (Array[String] args) -> bool
    def execute_command(args)
      command = args.shift || "help"
      command_class = Commands.for(command)

      if command_class
        command_class.new(
          args,
          configuration: @configuration,
          out: @out,
          err_out: @err_out,
          progress_formatter: @progress_formatter,
          offenses_formatter: @offenses_formatter,
        ).run
      else
        @err_out.puts("'#{command}' is not a packwerk command. See `packwerk help`.",)

        false
      end
    end
  end
end
