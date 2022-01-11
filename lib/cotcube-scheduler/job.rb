module Cotcube
  module Scheduler
    class Job include Helpers


      # the initialization of the job is quite long due to containing the entire 'inner' validation. 
      # @root is the path given in scheduler config
      # the filename includes the path relative to root plus the actual filename
      # @target is the path, where history and log output is written
      #
      def initialize(root:, filename:)
        @source   = filename[1..]
        @target   = "#{Cotcube::Scheduler::CONFIG[:data_path]}/#{source.split('/')[..-2].join('/')}"
        err = `mkdir -p #{target}`.chomp
        raise RuntimeError, "Could not create @target: #{target} for #{source} due to #{err}." unless $?.success?

        full_name = "#{root}/#{source}"
        @root     = root
        @message  = nil

        # quick helper to fail as well as break out of further intialization. know the diff between lambda and Proc.new
        fail_with = Proc.new{|message| invalidate(message); return }

        # loading and plain yaml parsing
        #
        fail_with.call "Cannot load job, file not existant"        unless File.exist? full_name
        fail_with.call "Cannot load job, reading the file failed." unless raw_yaml = (File.read(full_name) rescue false)
        fail_with.call "Cannot read YAML, parsing content failed." unless     yaml = (YAML.load(var_substitute raw_yaml)  rescue false)

        @config   = yaml.keys_to_sym!

        #checking and loading mandatory keys
        #
        fail_with.call "Missing mandatory keys: '#{MANDATORY_JOB_KEYS - config.keys}'." unless (MANDATORY_JOB_KEYS - config.keys).empty?
        @name     = config[:name]

        load_history

        #command might have the structure [ENV] <command> [params]
        #so we need to pick ENV, then check if command exists (by `which` and `File.exist?` and shell builtin)
        @command_hash  = Cotcube::Scheduler::CommandParser.parse( config[:command]  )
        fail_with.call "Command could not be parsed: #{command_hash[3]}" if command_hash.is_a? Array
        @command       = command_hash[:command] rescue ''
        fail_with.call "It seems #{command} does not exist or is not executable."        unless ->{ `/bin/bash -c 'type -t #{command}' > /dev/null`; $?.success? }.call
        fail_with.call "It seems #{command} is shell builtin, use /bin/bash -c '#{command}' instead." unless  ->{ `type #{command}  > /dev/null`; $?.success? }.call

        # durations and delays

        @run_duration     = config[ :run_duration]     || 0
        @duration_warning = config[ :duration_warning] || run_duration * 2
        @duration_error   = config[ :duration_error]   || run_duration * 4
        fail_with.call "durations must be given in seconds" unless [run_duration, duration_warning, duration_error].map{|z| z.is_a?(Numeric) && not(z.negative?) }.reduce(:&)
        @startup_delay    = config[ :startup_delay]    || 0
        @delay_warning    = config[ :delay_warning]    || 0
        @delay_error      = config[ :delay_error]      || 2 * delay_warning
        fail_with.call "output delays must be given in seconds" unless [delay_warning, delay_error].map{|z| z.is_a?(Numeric) && not(z.negative?) }.reduce(:&)

        # schedule start and (optional) schedule end
        #
        unless (@schedule_end = config[:schedule_start]).nil?
          fail_with.call "If given, schedule_start must be valid: '#{config[:schedule_start]}'."   unless @schedule_start = digest_cron(config[:schedule_start])
        end
        fail_with.call ':schedule_start is mandatory unless job is marked inactive.' if schedule_start.nil? and not config[:inactive]

        unless (@schedule_end = config[:schedule_end]).nil?
          fail_with.call "If given, schedule_end must be valid: '#{config[:schedule_end]}'." unless @schedule_end = digest_cron(config[:schedule_end])
        end

        # dependencies
        # - are checked by joblist
        # - are simply a list of names
        @dependencies = config[:dependencies] || []

        # validations
        # - are referring to the module Cotcube::Scheduler::Validations
        # - include: RC, grep-true/false/count ...
        @validations = config[:validations] || []
        validations.each do |validation|
          fail_with.call "Wrong validation spec: '#{validation}'." unless validation.size == 1 and validation.is_a? Hash
          method = validation.keys[0].to_s.downcase.to_sym
          params = validation.values[0]
          params = [ params ] unless params.is_a? Array
          fail_with.call "unknown validation: #{method}." unless Cotcube::Scheduler::VALID_VALIDATIONS.include? method
          val_error = Cotcube::Scheduler::VALID_VALIDATIONS[method].call(params)
          fail_with.call "Wrong spec for '#{method}': #{val_error}" unless val_error.empty?
        end

        # mitigations are just set here due to the missing OPTIONAL_JOB_KEYS check
        # TODO: mitigations
        @mitigations = config[:mitigations] || []

        @inactive = config[:inactive]
        missing_keys  = MANDATORY_JOB_KEYS.reject{|z| instance_variable_defined?("@#{z}") }
        missing_keys += OPTIONAL_JOB_KEYS.reject{|z|  instance_variable_defined?("@#{z}") }
        fail_with.call "Missing instance variables: #{missing_keys}" unless missing_keys.empty?
        @status   = :ready
        @message  = 'loading OK'
      end

      def quick_print(source: nil, id: nil, status: nil, message: nil)
            "#{format '%-40s', source || @source
         } | #{format '%6s',       id || @id
         } | #{format '%12.12s', name || @name
         } | #{format '%24.24s',         @command
         } | #{format '%10s', (status || @status).to_s
         } | #{               message || @message}"
      end

      def last;                    history.                                                 last;          end
      def last_succeeded;          history.select{|z| %w[ succeeded ].include? z[:status] }.last;          end
      def invalidate(message);     @status  = :invalid;   @message = message;                              end
      def schedule(message = nil); @status  = :scheduled; @message = message unless message.nil?;          end
      def postpone(message = nil); @status  = :postponed; @message = message unless message.nil?;          end
      def logfile;                 "#{target}/#{name}.jsonl";                                              end
      def lastlog(invalid: false); "#{target}/#{name}.#{invalid ? "invalid.#{invalid}" : "lastrun" }.log"; end

      def load_history(full: false, irb: false)
        binding.irb if irb
        jsonl = File.read(logfile) rescue ''
        @history = jsonl.
          each_line.
          map do |x|
            JSON.parse(x, symbolize_names: true).
              tap do |entry|
                entry[:start] = DateTime.parse(entry[:start]) rescue nil
                entry[:end]   = DateTime.parse(entry[:end])   rescue nil
                entry[:status] = entry[:status].downcase.to_sym rescue nil
              end
          end
        if [ nil, [], [nil] ].include? @history
          @history = [{status: :never, start: DateTime.now}]
        end
        @history = @history[-25..] if @history.size > 30 and not full
      end

      def average_duration
        (history.select{|z| z[:valid]}.map{|z| z[:duration]}.reduce(:+) / history.select{|z| z[:valid]}.count).round(3) rescue -1
      end

      def append_log(line, create: false)
        out = "#{ format('%8.3f ', line.first)
              }#{ format('%9s', line[-2] == line[-1] ? '' : line[1..-2].join(' '))
              }#{ line.last.strip.chomp }"
        unless out == format('%8.3f ', line.first)
          File.open(lastlog, create ? 'w' : 'a+') {|f| f.write(out + "\n") }
        end
      end

      def save_history(transmitter)
        result = {
          start:    transmitter[:start   ],
          status:   transmitter[:status  ],
          duration: transmitter[:duration].round(3),
          end:     (transmitter[:start   ] + transmitter[:duration]).round(3),
          rc:     ((transmitter[:rc      ] || 77   ) rescue 77   ),
          valid:  ((transmitter[:valid?  ] || false) rescue false)
        }
        unless result[:valid]
          file = lastlog(invalid: result[:start].strftime('%Y%m%d-%H%M%S'))
          File.open(file, 'w') {|f| f.write(transmitter.show_output(console: false)) } if transmitter.respond_to?(:show_output)
        end
        File.open(logfile, 'a+') {|f| f.write(result.to_json + "\n") }
        history << result
      end

      def inspect(deep: false)
        if deep 
          super()
        else
          "<Job:#{format '0x%05x', object_id
              } #{format '%-30.30s', ("#{source.split('/')[..-2].join('/')}/#{name}" rescue :error)
              } #{format '%-11.11s', status.inspect
            } [ #{format '%-11.11s', (last[:status] rescue :error).inspect
            } ] info: '#{message
            }'>"
        end
      end

      def to_h
        {
          name: name,
          status: status,
          last: last,
          next: schedule_start.next_time.strftime('%Y-%m-%d %H:%M:%S %Z'),
          message: message
        }
      end

      def [](attr)
        self.send(attr) rescue nil
      end

      def rebuild_command
        command_hash.values.flatten.join(' ')
      end

      attr_reader :status, :history, :config, :message, :source, :target, :id, :name,
        :command, :command_hash, :run, :run_thread, :startup_delay, :run_threshold,
        :run_duration, :duration_warning, :duration_error, :delay_warning, :delay_error,
        :dependencies, :mitigations, :validations, :schedule_start, :schedule_end

      # among last are:
      #   never    : job has not been run yet
      #   succeeded  : job has been completed without error (and result was valid)
      #
      #   failed   : job has been completed with error
      #   timed_out  : job could not be completed due to timeout of run window
      #   crashed  : job has not been completed, raised error on runtime
      #   unmet    : job could not been started due to unmet dependencies
      #              (in here counts crash/fail/timeout of any dependency)
      #            : job could not been started due to dependencies timed out
      #
      # returncodes aka rc:
      #   there are those return codes as given by the original script plus those:
      #        70  : job was stopped due to output delay (if you know the job did not
      #              deadlock, you might want to raise delay_* values)
      #        71  : job was stopped due to exceeding duration threshold
      #        72  : job was stopped due to reaching schedule_end
      #        73  : job did not validate although it got rc=0 from script
      #
      #        77  : rc could not be read from transmitter or was not provided
      #              (this might occur if the job was not even started)

    end
  end
end
