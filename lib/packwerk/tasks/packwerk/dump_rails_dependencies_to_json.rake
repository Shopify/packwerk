# typed: strict

module Packwerk
  # This rake task is in a class so that it can be strictly typed.
  class TaskLoader
    include Rake::DSL
    extend T::Sig

    sig { void }
    def create_tasks!
      namespace(:packwerk) do
        #
        # The purpose of this task is to give a rake command to output our dependencies on Rails in JSON format.
        # The reason we want this is because we don't want our `bin/packwerk` process to load Rails, since when we run Parallel.flat_map (in `parse_run.rb`),
        # we fork the process. `parallel` (https://github.com/grosser/parallel#processes) will create a new forked process that duplicates the memory space,
        # meaning we have X processes each with their own copy of the Rails app. We want to avoid this, so we want to only grab what we need from Rails in a single process,
        # and have the forked processes remain lightweight.
        # See https://github.com/Shopify/packwerk/issues/164 for bug report associated with this.
        #
        # Note that by default, `spring` will automatically springify all rake tasks run via `bin/rake` (https://github.com/rails/spring#rake).
        # So we should expect to see the fast execution of this task by the parent process.
        #
        # Lastly -- we do not expect clients to be using this task. It is only exposed so that the client-run `bin/packwerk` command can fork and run this command to get the STDOUT.
        # We reflect this by running this command with `WARNING="This is private API." bin/rake packwerk:dump_rails_dependencies_to_json`. Open to other suggestions
        # for incorporating this in a more conventionally private way.
        #
        desc('This prints out Rails dependencies to STDOUT.')
        task(dump_rails_dependencies_to_json: :environment) do |_task, _args|
          # TODO: Pass this in as an argument to the rake task
          root_path = File.expand_path('.')
          Packwerk::Diagnostics.log('Extracting load paths and inflections', __FILE__)
          load_paths = ApplicationLoadPaths.extract_relevant_paths(root_path, "test").count
          inflections = ActiveSupport::Inflector.inflections.as_json
          puts "Load path count: #{load_paths}"
          puts "Inflections (acronyms for brevity): #{inflections['acronyms']}"
          Packwerk::Diagnostics.log('Successfully extracted Rails data', __FILE__)
        end
      end
    end
  end
end

Packwerk::TaskLoader.new.create_tasks!
