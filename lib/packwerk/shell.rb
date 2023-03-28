# typed: strict
# frozen_string_literal: true

module Packwerk
  class Shell < Thor::Shell::Basic
    extend T::Sig

    sig do
      params(
        stdout: T.any(IO, StringIO),
        stderr: T.any(IO, StringIO),
        environment: String,
        progress_formatter: Formatters::ProgressFormatter,
        offenses_formatter: OffensesFormatter,
      ).void
    end
    def initialize(
      stdout:,
      stderr:,
      environment:,
      progress_formatter:,
      offenses_formatter:
    )
      super()
      @stdout = stdout
      @stderr = stderr
      @environment = environment
      @progress_formatter = progress_formatter
      @offenses_formatter = offenses_formatter
    end

    sig { returns(String) }
    attr_reader(:environment)

    sig { returns(Formatters::ProgressFormatter) }
    attr_reader(:progress_formatter)

    sig { returns(OffensesFormatter) }
    attr_reader(:offenses_formatter)

    protected

    sig { returns(T.any(IO, StringIO)) }
    attr_reader(:stdout)

    sig { returns(T.any(IO, StringIO)) }
    attr_reader(:stderr)
  end
end
