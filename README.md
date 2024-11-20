# AppConfigurable

Single source of truth for app configuration.

## Adding a new config

There are 2 types of configs:
 - Namespaced - used to store configs which could be grouped by attributes such as external service name e.g Hubspot. 
 - Root-level configs - generic configs for the app such as `rails_serve_static_files`.

Example of namespaced config:

```ruby
class AppConfig::Hubspot
  include AppConfigurable

  entry :access_token, default: 'secret'
  entry :base_url, default: 'https://app-eu1.hubspot.com/contacts/26265873', production: 'https://app-eu1.hubspot.com/contacts/25696692'
  entry :client_secret, default: 'secret'
end
```

Then config entries could be accessed through: `AppConfig::Hubspot.base_url`.

## Attributes
Attributes are declared using `entry` directive.
Example: `entry :rails_serve_static_files`.

### Options
`production/staging/development/test` - sets attributes per environment.

`default`:
- sets default attribute, used in `production/staging/development` environments as a fallback.
- accepts `string`/`number`/`boolean` as well as `Proc`/`Lambda` as a parameter.
- in `test` environment always falls back to a dummy value `some_super_dummy_#{namespaced_attribute_name}`

#### Priority and lifecycle:
  `production/staging/development`:
   1) Tries to find a value in joint hash of `ENV` and `Rails.application.credentials`.
   2) Gets value from specific environment attribute passed to `entry`.
   3) Get's value from `default`.
   4) Raises `AppConfig::Error::RequiredVarMissing` if no attribute found.

   `testing`:
   1) Tries to find a value in joint hash of `ENV` and `Rails.application.credentials`.
   2) Gets value from `test` environment attribute.
   3) Returns `some_super_dummy_#{namespaced_attribute_name}`, ignores specified `default` attribute.

### Setting the environment:
You could set environment per namespace like so:

Given namespace `AppConfig::MyNiceConfigClass` and `.env.staging`

```bash
APPCONFIG_MYNICEMODULE_ENV=staging rspec
```

*`.env.#{RAILS_ENV}` will be read per specific `AppConfig::SomeNiceClass` class.*

### Fail on startup:
Create a new initializer in `config/initializers/_app_config.rb`

```
# Require your config files
require './config/app_config' # Root-level configs.
FileList['./config/app_config/*.rb'].each { |file| require file } # Secondary-level/namespaced configs.

missing = AppConfigurable.missing_required_vars
missing.present? and raise "Missing required ENV variables/encrypted credentials: #{missing.inspect}"
```

### TODO:
 - Read `Rails.application.credentials`
    - Make dynamic switch possible, simillar to what we have with `ENV`.
