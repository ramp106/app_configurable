# frozen_string_literal: true

require 'app_configurable'
require 'rails'

ENV['RAILS_ENV'] ||= 'test'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.define_derived_metadata do |metadata|
    metadata[:aggregate_failures] = true
  end
end
