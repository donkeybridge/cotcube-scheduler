module Cotcube
  module Scheduler
    module Validations
      def grep_count(output, patterns)
        output.map{|line| 
          patterns.map{|pat| line.last.match(pat.is_a?(Regexp) ? pat : /#{pat}/) && true }.reduce(:|) 
        }.select{|result| result.is_a? TrueClass }.count
      end

      def grep_true(run, *patterns)
        grep_count(run[:output], patterns).positive?
      end

      def grep_false(run, *patterns)
        grep_count(run[:output], patterns).zero?
      end

      def grep_min(run, *patterns, x)
        grep_count(run[:output], patterns) >= x
      end

      def grep_max(run, *patterns, x)
        grep_count(run[:output], patterns) <= x
      end

      def grep_eq(run, *patterns, x)
        grep_count(run[:output], patterns) == x
      end

      def rc(run, *valid_return_codes)
        valid_return_codes.include? run[:rc]
      end

      module_function :grep_true,
        :grep_false,
        :grep_min,
        :grep_max,
        :grep_eq,
        :grep_count,
        :rc
    end
  end
end
