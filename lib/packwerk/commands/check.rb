# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class Check < Command
      extend T::Sig


      sig { returns(T::Boolean) }
      def check
        output_result(parse_run(args).check)
      end
    end
  end
end
