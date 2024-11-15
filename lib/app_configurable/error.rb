# frozen_string_literal: true

module AppConfigurable
  class Error < StandardError
    class InvalidValue < Error; end
    class RequiredVarMissing < Error; end
  end
end
