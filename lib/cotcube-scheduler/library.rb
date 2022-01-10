module Cotcube
  module Scheduler

    # The joblist is a collection of jobs and services
    # loaded from the jobs-path directory and validating them
    class Library
      def initialize(config: Cotcube::Scheduler::CONFIG, silent: false)
        @root = config[:jobs_path]
        @list = [] 
        @silent = silent
        dig_jobs root
        validate_dependencies
      end

      # dig_jobs recursively reads a directory structure and considers a YAML files in there to be jobs to load
      # the directory structure itself serves only to humans but does not provide a structure to joblist or batches
      #
      # NOTE: to ignore a specific file or directory tree, rename it ending on ignore(d)
      def dig_jobs(dir)
        Dir[dir + '/*' ].each do |file| 
          next if file.downcase =~ /ignored?$/ 
          if File.directory?(file)
            dig_jobs file
          elsif %w[yml yaml].include? file.split('.').last.downcase
            job = Job.new(root: root, filename: file.split(root).last)
            unless find_by_name(job.name).nil? or job.name.nil?
              # the following message actually is wrong, as the there is no job.status :duplicate
              puts job.quick_print(status: :duplicate, message: 'Cannot enqueue job, another job with same NAME already exists.')
              next
            end
            list << job
            # puts job.quick_print unless @silent
          end
        end
      end

      # dependency validation considers all jobs unless they are invalid
      # 
      # for each job all dependencies must be available
      #
      def validate_dependencies(mitigations = [])
        checklist = list.
          reject{|z| z[:invalid] }.
          map{|job| 
            { 
              name: job.name, 
              deps: job.dependencies.map{|z| z[:job] }, walk: [], miss: [], circular: []
            }
          }
        s_find = ->(dep) { checklist.find {|j| j[:name] == dep } }
        check_deps = -> (job, deps) {
          deps.each do |dep|
            if found = s_find.call(dep)
              found[:walk] << dep
              found[:deps].each do |next_dep|
                if next_dep == job[:name]
                  found[:circular] << found[:name]
                  return
                end
                check_deps.call(job,s_find.call(next_dep)[:deps].select{|d| not found[:walk].include?(d) })
              end
            else
              job[:miss] << dep
            end
          end
        }
        checklist.each do |job|
          actual_job = find_by_name job[:name]
          check_deps.call(actual_job, job[:deps])
          # validate, there no circular dependencies
          if not job[:circular].empty?
            actual_job.invalidate("Job has circular dependencies: #{job[:circular].join(', ')}.")
          # validate, there are all dependencies available
          elsif not job[:miss].empty?
            actual_job.invalidate("Job has missing dependencies: #{job[:miss].join(', ')}.")
          # validate, that no dependency is inactive
          # elsif not (postponed_dependencies = job[:walk].reject{|z| (not find_by_name(z)[:inactive]) or workaround.include?(z) }).empty?  
          #   actual_job.invalidate("Job has inactive (postponed) dependencies(: #{postponed_dependencies.join(', ')}.")
          # set job to :postponed if inactive
          end
        end
      end

      def get(incl: nil, excl: nil)
        incl = [ incl ] unless incl.nil? or incl.is_a? Array
        excl = [ excl ] unless excl.nil? or excl.is_a? Array
        list.
          select{ |job| incl.nil? ? true  : incl.include?(job.status) }.
          reject{ |job| excl.nil? ? false : excl.include?(job.status) }.
          sort_by{|job| job.source }.
          sort_by{|job| job.last[:status].to_s }.
          sort_by{|job| job.status}
      end

      # the following method is for inspection only as 
      # it is not logged to output
      def show(incl: nil, excl: nil)
        get(incl:incl, excl: excl).each {|job| p job.inspect}
      end


      def to_a
        list.map{|job| job.to_h }
      end

      def find_by_name(name)
        list.find{|job| job.name == name }
      end

      def [](name)
        find_by_name(name.to_s)
      end

      Cotcube::Scheduler::VALID_JOB_STATUS.each do |method| 
        define_method(method) do
          list.select{|job| job.status == method }
        end
      end

      # VALID_LAST_STATUS.each do |method|
      #   define_method(method) do
      #     list.select{|job| job.last[:status] == method }
      #   end
      # end

      attr_reader :list
      private
      attr_reader :root
    end
  end
end
