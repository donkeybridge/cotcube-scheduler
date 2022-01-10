module Cotcube
  module Scheduler
    module Helpers
      def digest_cron(str)
        ::Fugit::Cron.parse(str)
      end

      def var_substitute(str)
        subs = CONFIG[:substitutes]
        matches = str.scan(/{{(\s*\w+\s*)}}/).flatten
        matches.each do |match| 
          str.gsub!(/{{#{match.escape_regex}}}/, subs[match.strip]) if subs[match.strip].presence
        end
        functions = str.scan(/{{(\s*\w+\s*\([\w\s,\.]*\)\s*)}}/).flatten
        functions.each do |raw|
          func   = raw.strip.match(/^(?<name>\w+)\s*\(\s*(?<params>[\w\s,\.]+)?\s*\)$/)
          name   = func[:name].downcase
          params = func[:params]
          case name
          when 'random'
            str.gsub!(/{{#{raw.escape_regex}}}/, "#{(Random.rand(params.split(',').first.to_f) rescue 0).round(2)}")
          when *%w[ minute minutes mins ]
            str.gsub!(/{{#{raw.escape_regex}}}/, "#{1 * (params.split(',').first.to_f * 60).to_i}")
          when *%w[ hour hours ]
            str.gsub!(/{{#{raw.escape_regex}}}/, "#{1 * (params.split(',').first.to_f * 3600).to_i}")
          when *%w[ day days ]
            str.gsub!(/{{#{raw.escape_regex}}}/, "#{1 * (params.split(',').first.to_f * 3600 * 24).to_i}")
          when *%w[ week weeks ]
            str.gsub!(/{{#{raw.escape_regex}}}/, "#{1 * (params.split(',').first.to_f * 3600 * 24 * 7).to_i}")
          else
            raise RuntimeError, "During var_substitute: Found unknown function '#{func}' in \n\n#{str}"
          end
        end
        str
      end

      module_function :digest_cron, :var_substitute
    end
  end
end
