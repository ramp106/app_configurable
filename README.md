# App Configurable

## Single source of truth for app configuration

App Configurable is a simple Ruby gem that provides a centralized and consistent way to manage application configurations. It allows you to define configurations in a single place and access them throughout your application, ensuring that your app's settings are always up-to-date and consistent across different environments.

### Features
- Centralized configuration management
- Environment-specific settings
- Fail on demand or on app startup
- Support for namespaced and root-level configurations
- Easy integration with Rails applications

### Installation
1. Add the gem to your Gemfile:
    ```ruby
    gem 'app_configurable'
    ```
2. Define your configurations in `config/app_config.rb`:
    ```ruby
    class AppConfig
      include AppConfigurable

      entry :secret_key, default: 'your_secret_key'
      entry :base_url, default: 'http://my-site.local', production: 'http://  my-site.io', staging: 'http://staging.my-site.io'
    end
    ```
3. Load the configurations:
    
    Define an initializer `config/initializers/_app_config.rb`:
    ```ruby
    AppConfigurable.load_configs(%w[./config/app_config.rb])
    ```
    OR
    ```ruby
    AppConfigurable.load_configs(%w[./config/app_config.rb], raise_on_missing: true) #  Fails on startup, reporting missing configs.
    ```
    *Alternatively, you could define your configs under the autoloading path if   failing on demand is acceptable.*

4. Access your configurations:
    ```ruby
    AppConfig.secret_key
    ```

### Adding a config
There are two types of configurations:
- **Namespaced**: Used to store configurations grouped by attributes such as external service names (e.g., Hubspot).
- **Root-level configs**: Generic configurations for the app, such as `rails_serve_static_files`.

  ### Example
  `./config/app_config.rb`:
  ```ruby
  class AppConfig
    include AppConfigurable

    entry :secret_key_base, default: 'secret_key_base'
    entry :base_url, default: 'http://my-site.local', production: 'http://  my-site.io', staging: 'http://staging.my-site.io'
    entry :client_secret, default: 'client_secret_token'
  end
  ```

  `./config/app_config/hubspot.rb`:
  ```ruby
  class AppConfig::Hubspot
    include AppConfigurable

    entry :access_token, default: 'secret_access_token'
    entry :base_url, default: 'https://hubspot.com/1234', production: 'https:// hubspot.com/4321'
    entry :client_secret, default: 'client_secret_token'
  end
  ```

  Declared configs can be accessed through: `AppConfig.secret_key_base` and   `AppConfig::Hubspot.base_url`.

## Attributes

Attributes are declared using the `entry` directive.
Example: `entry :rails_serve_static_files`.

### Options
- **production/staging/development/test**: Sets attributes per environment.
- **default**:
  - Sets the default attribute, used in `production/staging/development` environments as a fallback.
  - Accepts `string`/`number`/`boolean` as well as `Proc`/`Lambda` as a parameter.
  - In the `test` environment, always falls back to a dummy value `some_super_dummy_#{namespaced_attribute_name}` unless specified explicitly.

#### Priority
- **production/staging/development**:
  1. Find value in `ENV`.
  2. Find value in specific environment attribute passed to `entry`.
  3. Find value from `default`.
  4. Fail with `AppConfig::Error::RequiredVarMissing`.

- **testing**:
  1. Find value in `ENV`.
  2. Find value in `test` attribute of config `entry`.
  3. Return `some_super_dummy_#{namespaced_attribute_name}`, **ignoring the specified `default` attribute**.

### Setting the Environment
You can set the environment per namespace like so:

Given namespace `AppConfig::MyNiceConfigClass` and `.env.staging`:

```bash
APPCONFIG_MYNICEMODULE_ENV=staging rspec
```

`.env.#{RAILS_ENV}` will be read per specific `AppConfig::SomeNiceClass` class.

### TODO:

- Read `Rails.application.credentials`.
- Make dynamic switch possible, similar to what we have with `ENV`.