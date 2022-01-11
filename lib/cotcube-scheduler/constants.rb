module Cotcube
  module Scheduler

    VALID_JOB_STATUS   = [ 
      :ready,        # the job has passed Job and Library validations, but for now it is not used
      :invalid,      # the job has been tried to load, but was found to be invalid (see message)
      :scheduled,    # the job has been scheduled to start at some point in the future
      :waiting,      # the job was released but waits for other jobs to complete to meet dependencies
      :running,      # the job is currently running in a RunEnv
      :inactive,     # the job was set to inactive manually, probably just hold aside to be used in mitigations
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

    SECRETS_DEFAULT = {
      'josch_mq_proto'    => 'http',
      'josch_mq_user'     => 'guest',
      'josch_mq_password' => 'guest',
      'josch_mq_host'     => 'localhost',
      'josch_mq_port'     => '15672',
      'josch_mq_vhost'    => '%2F'
    }

    include Cotcube::Helpers
    CONFIG = init

    # Load a yaml file containing actual parameter and merge those with current
    SECRETS = SECRETS_DEFAULT.merge(
      lambda {
	begin
	  YAML.safe_load(File.read(Cotcube::Helpers.init[:secrets_file]))
	rescue StandardError
	  {}
	end
      }.call.select{|z| z.split('_').first == 'josch' }
    )



  end
end
