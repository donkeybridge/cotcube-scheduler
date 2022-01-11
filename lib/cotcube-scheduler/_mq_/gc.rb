# about garbage collection, i.e. periodically check for unused artifacts and clean them 
#
module Cotcube
  module Scheduler
    class Scheduler

      def gc_start
        if gc_thread.nil?
          @gc_thread = Thread.new do 
            loop do
              sleep 30 + 2 * Random.rand
              gc
            end
          end
          log 'GC_INFO: GC spawned.'
        else
          log 'GC_ERROR: Cannot start GC_THREAD more than once.'
        end
      end

      def gc_stop
        if gc_thread.nil?
          log 'GC_ERROR: Cannot stop nonexisting GC_THREAD.'
          false
        else
          gc_thread.kill
          gc_thread = nil
          log 'GC_INFO: GC stopped.'
          true
        end
      end

      def gc
        get_mq(list: false).each do |item_type, items|
          items.each do |key, item| 
            case item_type
            when :bindings
              # NOTE if might be considerable to unbind unused queues from exchanges before removing either
              #      as the bound value of the exchange will decrease it might be removed on next run of GC
            when :queues
              next if item[:consumers].nil? or item[:consumers].positive?
              delete_mq(type: item_type, instance: item[:name]) 
              log "GC_INFO: Deleted unsed queue: #{item}."
            when :exchanges
              if item[:name].empty? or item[:name] =~ /^amq\./ or item[:bound].count.positive? or 
                  %w[ josch_commands josch_replies ].include? item[:name]
                next
              end
              log "GC_INFO: found superfluous exchange '#{item[:name]}'"
            else
              log "GC_ERROR: Unexpected type '#{item_type}' in GarbageCollector"
            end
          end
        end
      end

      def get_mq(list: true)
        bindings = api(type: :bindings) 
        results  = {} 
        %i[ queues exchanges ].each do |type|
          results[type] = {}  
          items = api type: type
          items.each do |item| 
            query_name = item[:name].empty?  ? 'amq.default' : item[:name]
            results[type][item[:name]] = api type: type, instance: query_name
            results[type][item[:name]][:bound] = bindings.select{|z| z[:source] == item[:name] }.map{|z| z[:destination]} if type == :exchanges
          end
        end
        results.each do |type, items|
          items.each do |key,item|
            if item.is_a? Array
              log "#{key}\t\t#{item}"
              next
            end
            log "#{format '%12s', type.to_s.upcase}    #{
            case type
            when :queues 
              "Key: #{format '%-30s', key}  Cons: #{item[:consumers]}"
            when :exchanges
              "Key: #{format '%-30s', key}  Type: #{format '%10s', item[:type]}   Bound: #{item[:bound].presence || 'None.'}"
            else
              "Unknown details for #{type}"
            end
          }" 
          end
        end if list
        results[:bindings] = bindings
        results
      end

      def delete_mq(type:, instance: )
        allowed_types = %i[ queues exchanges ]
        raise ArgumentError, "Type must be in '#{allowed_types}', but is  '#{type}'" unless allowed_types.include? type
        result = HTTParty.delete("#{SECRETS['josch_mq_proto']
                            }://#{SECRETS['josch_mq_user']
                              }:#{SECRETS['josch_mq_password']
                              }@#{SECRETS['josch_mq_host']
                              }:#{SECRETS['josch_mq_port']
                          }/api/#{type.to_s
                           }/dp/#{instance}", query: { 'if-unused' => true })
        if result.code == 204
          result = { error: 0}
        else
          result = JSON.parse(result.body, symbolize_names: true)
          result[:error] = 1
        end
        result
      end

      def api(type:, instance: nil)
        allowed_types = %i[ queues exchanges bindings ] # other types need different API sepc: channels connections definitions
        raise ArgumentError, "Type must be in '#{allowed_types}', but is  '#{type}'" unless allowed_types.include? type
        req = "#{type.to_s}/#{SECRETS['josch_mq_vhost']}#{instance.nil? ? '' : "/#{instance}"}"
        JSON.parse(HTTParty.get("#{SECRETS['josch_mq_proto']
                           }://#{SECRETS['josch_mq_user']
                             }:#{SECRETS['josch_mq_password']
                             }@#{SECRETS['josch_mq_host']
                             }:#{SECRETS['josch_mq_port']
                         }/api/#{req}").body, symbolize_names: true)
      end

    end
  end
end
