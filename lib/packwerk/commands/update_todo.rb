# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class UpdateTodo < Command
      extend T::Sig

      class << self
        extend T::Sig

        sig { returns(String) }
        def description
          "update package_todo.yml files"
        end
      end

      sig { returns(T::Boolean) }
      def update_todo
        output_result(parse_run(args).update_todo)
      end
    end
  end
end
