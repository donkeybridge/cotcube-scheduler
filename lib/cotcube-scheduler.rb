# frozen_string_literal: true
#

require 'active_support'
require 'active_support/core_ext/time'
require 'active_support/core_ext/numeric'
require 'colorize'
require 'outputhandler'
require 'date'    unless defined?(DateTime)
require 'csv'     unless defined?(CSV)
require 'yaml'    unless defined?(YAML)
require 'cotcube-helpers'
include Cotcube::Helpers
require 'raabro'
require 'fugit'

%w[ constants helpers command_parser library job scheduler validations ].each do |part|
  require_relative "cotcube-scheduler/#{part}"
end

module Cotcube
  module Scheduler

    # please note that module_functions of sources provided in non-public files must slso be published within these
  end
end

