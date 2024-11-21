# frozen_string_literal: true

require_relative 'lib/app_configurable/version'

Gem::Specification.new do |spec|
  spec.name = 'app_configurable'
  spec.version = AppConfigurable::VERSION
  spec.authors = ['Dmytro Pasichnyk']
  spec.email = ['dmytro.pasichnyk@omr.com']

  spec.summary = 'AppConfigurable allows you to configure your application with a simple DSL including environment-specific configuration, define fallbacks etc.'
  spec.description = spec.summary
  spec.homepage = 'https://github.com/ramp106/app_configurable.git'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ramp106/app_configurable.git'
  spec.metadata['changelog_uri'] = 'https://github.com/ramp106/app_configurable/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0").reject do |f|
        (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
      end
    end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'dotenv'

  spec.add_development_dependency 'rails', '> 7.1'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.21'
  spec.add_development_dependency 'rubocop-performance', '~> 1.23.0'
  spec.add_development_dependency 'rubocop-rails', '~> 2.27.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.2.0'
  spec.add_development_dependency 'rubocop-rspec_rails', '~> 2.30.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
