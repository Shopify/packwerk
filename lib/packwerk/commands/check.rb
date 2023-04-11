# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class Check < Command
      extend T::Sig

      class << self
        extend T::Sig

        sig { returns(String) }
        def description
          "run all checks"
        end
      end

      sig { returns(T::Boolean) }
      def check
        output_result(parse_run(args).check)
      end
    end
  end
end
