# frozen_string_literal: true
# typed: strict

module Packwerk
  # This rake task is in a class so that it can be strictly typed.
  module RailsDependencies
    class TaskLoader
      include Rake::DSL
      extend T::Sig

      sig { void }
      def create_tasks!
        namespace(:packwerk) do
          # The purpose of this task is to give a rake command to output our dependencies on Rails in JSON format.
          desc("This saves Rails dependencies to #{DUMP_FILE}.")
          task(dump_rails_dependencies_to_file: :environment) do |_task, _args|
            require 'pry'
            warning = ENV["WARNING"]&.strip
            if warning != "This is private API."
              raise "bin/rake packwerk:dump_rails_dependencies_to_file is private API and is subject to change."
            end

            Dump.dump!
          end
        end
      end
    end

    TaskLoader.new.create_tasks!
  end
end
