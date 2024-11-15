# frozen_string_literal: true

require_relative 'app_configurable/version'

require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'
require 'active_support/string_inquirer'

require 'dotenv'

module AppConfigurable
  @@available_config_attributes = [] # rubocop:disable Style/ClassVars

  def self.included(owner)
    owner.extend ClassMethods
    owner.include InstanceMethods
  end

  def self.available_config_attributes
    @@available_config_attributes
  end

  # Report missing required `ENV` variables.
  # @return [Array]
  def self.missing_required_vars
    out = []

    available_config_attributes.each do |method|
      method.call
    rescue Error::RequiredVarMissing
      out << "#{method.receiver.name}.#{method.name}"
    end
    out
  end

  module ClassMethods
    #--------------------------------------- Service
    # return [Array]
    def config_attributes
      @config_attributes
    end

    # @param value [String]
    # return [Boolean]
    def env_value_boolean?(value)
      env_value_truthy?(value) || env_value_falsey?(value)
    end

    # `true` if value is falsey.
    #
    #   # These are falsey.
    #   DEBUG=0
    #   DEBUG=-1
    #   DEBUG=false
    #   DEBUG=f
    #   DEBUG=no
    #   DEBUG=disabled
    #
    # @param value [String]
    # @return [Boolean]
    def env_value_falsey?(value)
      %w[0 -1 false f n no disabled].include? value.to_s.downcase
    end

    # `true` if value is truthy.
    #
    #   # These are truthy.
    #   DEBUG=1
    #   DEBUG=true
    #   DEBUG=y
    #   DEBUG=yes
    #   DEBUG=enabled
    #
    # @param value [String]
    # @return [Boolean]
    def env_value_truthy?(value)
      %w[1 true y yes enabled].include? value.to_s.downcase
    end

    # @param name [Symbol/String]
    # @param default [Proc/String]
    # @param development [String]
    # @param production [String]
    # @param staging [String]
    # @param test [String]
    # @return [void] Defines a class/instance getters for `name`.
    def entry(name, default: nil, development: nil, production: nil, staging: nil, test: nil) # rubocop:disable Metrics/AbcSize
      defined?(@config_attributes) ? @config_attributes << name : @config_attributes = [name]

      define_method(name) do
        preset_value = { development:, production:, staging:, test: }[rails_env.to_sym]

        if instance_variable_defined?(:"@#{name}")
          instance_variable_get(:"@#{name}")
        else
          instance_variable_set(:"@#{name}", per_env_value_fallback_for(name, default:, preset: preset_value))
        end
      end

      define_singleton_method(name.to_s, -> { instance.public_send(name) })
      AppConfigurable.available_config_attributes << method(name)
    end

    # @return [AppConfigurable]
    def instance
      @instance ||= new
    end

    delegate :rails_env, to: :instance
  end

  module InstanceMethods
    require_relative 'app_configurable/error'

    def initialize(attrs = {})
      attrs.each { |k, v| public_send(:"#{k}=", v) }
    end

    # A *copy* of the credentials for value-reading purposes.
    # @return [Hash]
    def credentials
      @credentials ||= ::Rails.application&.credentials.to_h
    end

    # A *copy* of the environment for value-reading purposes.
    # @return [Hash]
    def env
      @env ||= ::Rails.env == rails_env ? ENV.to_h : ::Dotenv.parse(".env.#{rails_env}")
    end

    # @!attribute rails_env
    # @return [ActiveSupport::StringInquirer] Default is `Rails.env`.
    def rails_env
      @rails_env ||= submodule_env || ::Rails.env
    end

    def rails_env=(value)
      @rails_env =
        begin
          wrapper_klass = ActiveSupport::StringInquirer
          value.is_a?(wrapper_klass) ? value : wrapper_klass.new(value)
        end
      recalculate_env
      recalculate_values
    end

    # @return [ActiveSupport::StringInquirer/nil]
    def submodule_env
      @submodule_env ||=
        begin
          class_name = self.class.name
          if class_name
            selector = "#{class_name.parameterize(separator: "_")}_ENV"
            env_string = ENV.fetch(selector.upcase, nil)
            ActiveSupport::StringInquirer.new(env_string) if env_string
          end
        end
    end

    #--------------------------------------- `ENV` management
    private

    # @see #env_truthy?
    # @param [String]
    # @return [Boolean]
    def env_boolean?(key)
      env_falsey?(key) || env_truthy?(key)
    end

    # @see #env_truthy?
    def env_falsey?(key)
      self.class.env_value_falsey?(secrets[key.to_s])
    end

    # @param key [String/Symbol]
    # @return [String/Boolean] The value of the environment variable, converts `bolean`'ish values into boolean.
    def env_value(key)
      v = secrets.dig(*key)
      v = env_truthy?(key) if env_boolean?(key)
      v
    end

    # `true` if environment variable `key` is truthy.
    #
    #   env_truthy? "WITH_HTTP"   # => `true` or `false`
    #   env_truthy? :WITH_HTTP    # same as above
    #
    # @param key [String]
    # @return [Boolean]
    def env_truthy?(key)
      self.class.env_value_truthy?(secrets[key.to_s])
    end

    # @param name [Symbol/String]
    # @param default [Proc/String]
    # @param preset [String]
    # @raise [Error::RequiredVarMissing]
    # @return [String]
    def per_env_value_fallback_for(name, default: nil, preset: nil)
      namespace = self.class.name&.[](/(?<=::).*$/)&.underscore.to_s
      key = namespace.empty? ? name : "#{namespace}_#{name}"
      default_value = per_env_default_value_fallback(default)
      dummy_value = "some_super_dummy_#{key}"

      result = env_value(key)
      result = preset if result.nil?
      result = default_value.call(dummy_value) if result.nil?
      if result.nil?
        raise Error::RequiredVarMissing,
              "Required ENV variable or credential missing: #{self.class.name}.#{name}"
      end

      result
    end

    # @param default [Proc/String]
    # @return [Proc]
    def per_env_default_value_fallback(default)
      if rails_env.test?
        ->(dummy) { dummy }
      else
        default.is_a?(Proc) ? default : ->(_) { default }
      end
    end

    # Recalculates the `env` hash.
    # @return [void]
    def recalculate_env
      remove_instance_variable(:@env) if instance_variable_defined?(:@env)
      send(:env)
    end

    # TODO: Implement this. Currently it's not re-reading secrets after enviromnemt change.
    # Recalculates the `credentials` hash.
    # @return [void]
    def recalculate_credentials
      remove_instance_variable(:@credentials) if instance_variable_defined?(:@credentials)
      send(:credentials)
    end

    # Recalculates the values of all the attributes.
    # @return [void]
    def recalculate_values
      self.class.config_attributes.each do |a|
        remove_instance_variable(:"@#{a}") if instance_variable_defined?(:"@#{a}")
        send(a)
      end
    end

    # Joint hash of `ENV` and `Rails.application.credentials`
    # @return [HashWithIndifferentAccess]
    def secrets
      { **env }.deep_transform_keys!(&:downcase).with_indifferent_access
    end
  end
end
