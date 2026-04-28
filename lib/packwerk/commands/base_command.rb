# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class BaseCommand
      extend T::Sig
      extend T::Helpers
      abstract!

      @description = "" #: String

      class << self
        extend T::Sig

        #: (?String? description) -> String
        def description(description = nil)
          if description
            @description = description
          else
            @description
          end
        end
      end

      #: (
      #|   Array[String] args,
      #|   configuration: Configuration,
      #|   out: (StringIO | IO),
      #|   err_out: (StringIO | IO),
      #|   progress_formatter: Formatters::ProgressFormatter,
      #|   offenses_formatter: OffensesFormatter
      #| ) -> void
      def initialize(args, configuration:, out:, err_out:, progress_formatter:, offenses_formatter:)
        @args = args
        @configuration = configuration
        @out = out
        @err_out = err_out
        @progress_formatter = progress_formatter
        @offenses_formatter = offenses_formatter
      end

      # @abstract
      #: -> bool
      def run = raise NotImplementedError, "Abstract method called"

      private

      #: Array[String]
      attr_reader :args

      #: Configuration
      attr_reader :configuration

      #: (StringIO | IO)
      attr_reader :out

      #: (StringIO | IO)
      attr_reader :err_out

      #: Formatters::ProgressFormatter
      attr_reader :progress_formatter

      #: OffensesFormatter
      attr_reader :offenses_formatter
    end
  end
end
