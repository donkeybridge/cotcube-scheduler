module Cotcube
  module Scheduler
    class Scheduler

      %w[ client_response commserver gc ].each do |part|
        require_relative "_mq_/#{part}"
      end

      def initialize(
        outputhandler: OutputHandler.new(
          location: Cotcube::Scheduler::CONFIG[:data_path] + '/log'
        )
      )
        @output = outputhandler
        @library = Cotcube::Scheduler::Library.new
        show_library
        @mq     = Cotcube::Scheduler::Helpers.get_mq_client
        if %i[ request_exch replies_exch request_queue ].map{|z| mq[z].nil? }.reduce(:|)
          log 'Could not connect to RabbitMQ, exiting.'
          exit 1
        end
        @gc_thread = nil
        commserver_start
        gc_start
        heartbeat_start
      end

      def show_library
        log library.show_library(terminal: false)
      end


      def shutdown
        log "Shutting down JoSch."
        heartbeat_stop
        commserver_stop
        gc_stop
        mq[:commands].close
        mq[:channel].close
        mq[:connection].close
        sleep 1
        gc
        log "... done."
      end

      def log(msg)
        output.puts "#{DateTime.now.strftime('%Y%m%d-%H:%M:%S:  ')}#{msg.to_s.scan(/.{1,#{Cotcube::Scheduler::CONFIG[:output_width] || 120}}/).join("\n" + ' ' * 20)}"
      end


      private
      attr_reader :client, :clients, :mq, :requests, :req_mon, :gc_thread, :output, :library

      # the heartbeat ticks once a minute and prepare 1 minute in advance the jobs to be run
      def heartbeat_start
        @last_heartbeat    = Time.now

        # the heartbeat queue transmits the heartbeat from the heartbeat thread to
        #     the heartbeat processor
        @redux_queue   = Queue.new
        @spawn_queue   = Queue.new

        # the heartbeat monitor watches all changes on the joblist (should its name then be joblist_monitor??)
        @heartbeat_monitor = Monitor.new

        # the heart beats each minute with an offset of 30 seconds
        # then  it first triggers the reduce_queue, which takes care of running/finished jobs 
        # afterwards it  triggers the spawn_queue , which takes care of spawning new runenvs 
        @heartbeat  = Thread.new do 
          loop do 
            sleep 1 while (Time.now - last_heartbeat) < 5
            sleep DateTime.now.seconds_until_next_minute(offset: 30) + 0.05
            redux_queue << Time.now
            sleep 9.989
            spawn_queue  << Time.now
            @last_heartbeat = Time.now
          end
        end


        @redux_processor = Thread.new do 
          while heartbeat = redux_queue.pop
            log "Beating in redux: #{heartbeat}"
          end
        end

        @spawn_processor  = Thread.new do 
          while heartbeat = spawn_queue.pop
            log "Beating in spawn: #{heartbeat}"
          end
        end
      end        

      def heartbeat_stop
        heartbeat.kill
        spawn_processor.kill
        redux_processor.kill
      end

      attr_reader :heartbeat_monitor, :heartbeat, :last_heartbeat, 
        :redux_queue, :redux_processor,
        :spawn_queue, :spawn_processor
    end
  end
end
