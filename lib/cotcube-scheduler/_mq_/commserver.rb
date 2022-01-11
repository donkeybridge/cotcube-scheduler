# frozen_string_literal: true

module Cotcube
  module Scheduler
    class Scheduler
      def commserver_start
        mq[:request_subscription] = mq[:request_queue].subscribe do |delivery_info, properties, payload|

          ################################################################################################
          # the request will be JSON decoded. The generic command 'failed' will be set, if decoding raises.
          # furthermore, __id__ and __to__ are extracted and added to the request-hash
          #
          request    = JSON.parse(payload, symbolize_names: true) rescue { command: 'failed' }
          request[:command] ||= 'nil'

          request[:__id__] = properties[:correlation_id]
          request[:__to__] = properties[:reply_to]

          if request[:debug] 
            log "Received \t#{delivery_info.map{|k,v| "#{k}\t#{v}"}.join("\n")
                     }\n\n#{properties   .map{|k,v| "#{k}\t#{v}"}.join("\n")
                     }\n\n#{request      .map{|k,v| "#{k}\t#{v}"}.join("\n")}" if request[:debug]
          else
            log "Received\t#{request}"
          end

          ###############################################################################################
          # the entire set of command processing,
          # starting with the (generic) 'failed' command, that just answers with the failure notice
          # and      with another failure notice upon a missing command section in the request
          # ending   with another failure notice, if an unknown command was issued
          #
          log "Processing #{request[:command]}:"
          case request[:command].downcase
          when 'failed'
            client_fail(request) { "Failed to parse payload: '#{payload}'." }

          when 'nil'
            client_fail(request) { "missing :command in request: '#{request}'." }

            ##############################################################################################
            # ping -> pong, just for testing
            # 
          when 'ping'
            client_success(request) { "pong" }

          when 'list', 'jobs'
            client_success(request) { joblist.to_a }

          when 'reload'
            list = load_joblist
            client_fail(request) { 'Could not reload joblist, please run drychecks first. (Keeping old configuration).' } unless list
            @joblist = list
            # TODO: Here is not taken care of currently running jobs for the moment
            client_success(request) { 'Joblist reloaded' }

          else
            client_fail(request) { "Unknown :command '#{request[:command]}' in '#{request}'." }
          end
        end
        log "Started commserver listening on #{mq[:request_queue]}"
      end

      def commserver_stop
        mq[:request_subscription].cancel
        log "Stopped Scheduler's commserver ..."
      end

    end
  end
end
