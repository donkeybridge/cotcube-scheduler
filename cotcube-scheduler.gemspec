# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'cotcube-scheduler'
  spec.version       = File.read("#{__dir__}/VERSION")
  spec.authors       = ['Benjamin L. Tischendorf']
  spec.email         = ['donkeybridge@jtown.eu']

  spec.summary       = 'The job scheduling part of the cotcube suite'
  spec.description   = 'This job scheduler is part of the cotcube-suite. It allows for cron-like scheduling, but also includes chaining, RC and output validation, idle/freeze alerting and restart/kill enforcement. It is a replacement for cotcube-eox.'

  spec.homepage      = 'https://github.com/donkeybridge/' + spec.name
  spec.license       = 'BSD-3-Clause'
  spec.required_ruby_version = Gem::Requirement.new('~> 2.7')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage + '/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport',      '~> 7'
  spec.add_dependency 'colorize',           '~> 0.8'
  spec.add_dependency 'fugit',              '~> 1'
  spec.add_dependency 'raabro',             '~> 1'
  spec.add_dependency 'cotcube-helpers',    '~> 0.2'
  spec.add_dependency 'yaml',               '~> 0.1'

  spec.add_development_dependency 'rake',   '~> 13'
  spec.add_development_dependency 'rspec',  '~> 3.6'
  spec.add_development_dependency 'yard',   '~> 0.9'
end