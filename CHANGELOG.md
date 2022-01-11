## 0.1.2 (January 11, 2022)
  - library: fixing false negative validation of circular deps
  - scheduler and job: few minor improvements
  - adding the basic scheduler class, and enabling it in core loader file
  - adding the (more or less) generic gc, client_response and commserver via _mq_ directory
  - helpers: imported :get_mq_client
  - job: removed status :ready in favor of earlier :ready
  - constants: added josch SECRETS loader
  - added basic validations for runenv output validation

## 0.1.1 (January 10, 2022)
  - adding job, the class the handles config and status tracking for each jobs
  - importing constants, command_parser and helpers from cotcube-eox

## 0.1.0 (January 10, 2022)
  - added current examples for a job-config and scheduler-config
  - added Gemfile and gemspec
  - Initial commit

