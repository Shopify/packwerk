# typed: strict

module Packwerk
  # A temporary class that will not land on production to help understand things.
  class Diagnostics
    extend T::Sig

    sig { params(message: String, file_location: String).void }
    def self.log(message, file_location)
      # Fom https://stackoverflow.com/questions/7220896/get-current-ruby-process-memory-usage
      pid, size = `ps ax -o pid,rss | grep -E "^[[:space:]]*#{$$}"`.strip.split.map(&:to_i)
      if pid != Process.pid
        raise "Something unexpected is happening: pid is #{pid} from system call but #{Process.pid} from Ruby call"
      end
      truncated_location = Pathname.new(file_location).basename
      puts "Diagnostics: #{{ msg: message, file: truncated_location.to_s, pid: Process.pid, rails_is_defined: !!defined?(Rails), memory: size }}"
    end
  end
end
