# frozen_string_literal: true
# typed: strict

module Packwerk
  #
  # The purpose of this module is to provide an interface to dump rails dependencies to STDOUT and read them and parse
  # them from STDOUT.
  #
  # The reason we want this is because we don't want our `bin/packwerk` process to load Rails, since when we run
  # Parallel.flat_map (in `parse_run.rb`), we fork the process. `parallel`
  # (https://github.com/grosser/parallel#processes) will create a new forked process that duplicates the memory space,
  # meaning we have X processes each with their own copy of the Rails app. We want to avoid this, so we want to only
  # grab what we need from Rails in a single process, and have the forked processes remain lightweight.
  #
  # See https://github.com/Shopify/packwerk/issues/164 for bug report associated with this.
  #
  # With this module, we can create a new process which runs `dump.rake` and we can read the input in in
  # the main process.
  #
  # Note that by default, `spring` will automatically springify all rake tasks run via `bin/rake`
  # (https://github.com/rails/spring#rake)
  # So we should expect to see the fast execution of this task by the parent process.
  #
  # Lastly - we do not expect clients to be using this task. It is only exposed so that the client-run
  # `bin/packwerk` command can fork and run this command to get the STDOUT. We reflect this by running this
  # command with `WARNING='This is private API.' bin/rake packwerk:dump_rails_dependencies_to_json`.
  # Open to other suggestions for incorporating this in a more conventionally private way.
  # (Note we could also use `Process.fork`, but we wouldn't be able to take advantage of spring in this case.)
  #
  module RailsDependencies
    extend T::Sig

    DUMP_DIRECTORY = T.let(Pathname.new("tmp"), Pathname)
    DUMP_FILE = T.let(DUMP_DIRECTORY.join("packwerk_rails_dependencies.out"), Pathname)

    class Result < T::Struct
      const :load_paths, T::Array[String]
      const :inflector, Inflector
    end

    sig { params(root_path: String, environment: String).returns(Result) }
    def self.fetch_load_paths_and_apply_inflections!(root_path, environment)
      unless File.exist?("bin/rake")
        warning = <<~WARNING
          DEPRECATION WARNING: Packwerk uses the `bin/rake` command to pull what we need Rails performantly without causing memory issues.
          If you do not have this file, we will fall back to loading Rails dependencies within the same process, which will greatly increase
          the amount of memory your packwerk process will use.
        WARNING

        warn(warning)

        return Load.load_from_rails_directly!(root_path, environment)
      end

      command = "WARNING='This is private API.' bin/rake packwerk:dump_rails_dependencies_to_json"
      _stdout, stderr, status = Open3.capture3(command)
      if status.success?
        Load.load_from_file!
      else
        # We may want to do something more elegant with errors. For now, printing to console
        # will at least allow bug reports to be filed.
        error_message = <<~ERROR
          Internal call to dump_rails_dependencies_to_json failed with errors:

          #{stderr}

          Please file a bug report!
        ERROR
        raise error_message
      end
    end
  end

  private_constant :RailsDependencies
end
