module Cotcube
  module Scheduler

    VALID_JOB_STATUS   = [ 
      :valid,        # the job has passed Job validations, but pending dependency validation
      :ready,        # the job has passed Job and Library validations, but for now it is not used
      :invalid,      # the job has been tried to load, but was found to be invalid (see message)
      :scheduled,    # the job has been scheduled to start at some point in the future
      :waiting,      # the job was released but waits for other jobs to complete to meet dependencies
      :running,      # the job is currently running in a RunEnv
      :custom_1,     # placeholder
      :custom_2      # placeholder
    ]

    # VALID_LAST_STATUS  = %i[ never succeeded failed timed_out crashed unmet batch_timed_out ]

    MANDATORY_JOB_KEYS = %i[ name command run_duration ]
    OPTIONAL_JOB_KEYS  = %i[ inactive schedule_start schedule_end startup_delay duration_warning duration_error delay_warning delay_error dependencies validations mitigations ]

    VALID_VALIDATIONS  = {
      grep_true:  ->(x){ rais = x.elem_raises?{|z| ''.match(/#{z}/) }; rais ? "invalid regex: #{rais}" : '' },
      grep_false: ->(x){ rais = x.elem_raises?{|z| ''.match(/#{z}/) }; rais ? "invalid regex: #{rais}" : '' },
      grep_min:   ->(x){ rais = x.elem_raises?{|z| ''.match(/#{z}/) }; rais ? "invalid regex: #{rais}" : not(x.last.is_a?(Integer)) ? 'last elem must be number' : (x.size < 2) ? 'must contains pattern(s) and number' : '' },
      grep_max:   ->(x){ rais = x.elem_raises?{|z| ''.match(/#{z}/) }; rais ? "invalid regex: #{rais}" : not(x.last.is_a?(Integer)) ? 'last elem must be number' : (x.size < 2) ? 'must contains pattern(s) and number' : '' },
      grep_eq:    ->(x){ rais = x.elem_raises?{|z| ''.match(/#{z}/) }; rais ? "invalid regex: #{rais}" : not(x.last.is_a?(Integer)) ? 'last elem must be number' : (x.size < 2) ? 'must contains pattern(s) and number' : '' },
      rc:         ->(x){ x.map{|z| z.is_a? Integer}.reduce(:&) ? '' : 'given return code must be integers' }
    }

    include Cotcube::Helpers
    CONFIG = init
  end
end
