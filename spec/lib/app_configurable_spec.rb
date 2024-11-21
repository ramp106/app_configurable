# frozen_string_literal: true

RSpec.describe AppConfigurable do
  let(:const_name) { 'AppConfigTest' }
  let(:current_env) { ENV.to_h.deep_transform_keys!(&:downcase).with_indifferent_access }
  let(:host_class) do
    Class.new do
      include AppConfigurable

      entry :attr1
      entry :attr2, default: 'first_att_default_value'
      entry :attr3, default: true
      entry :attr4, default: 'string1', production: 'string2', staging: 'string3', development: 'string4',
                    test: 'string5'
      entry :attr5
    end
  end

  before do |example|
    next if example.metadata[:skip_host_class]

    stub_const(const_name, host_class)
  end

  after do
    app_configs =
      described_class.available_config_attributes.reject do |c|
        c.receiver.name.start_with?('AppConfigTest')
      end
    described_class.class_variable_set(:@@available_config_attributes, app_configs) # rubocop:disable  Style/ClassVars
  end

  describe 'class methods' do
    describe '.available_config_attributes' do
      context 'when there are classes with `AppConfigurable` module included' do
        it 'returns a list of available config attributes' do
          expect(described_class.available_config_attributes.map(&:name)).to eq %i[attr1 attr2 attr3 attr4 attr5]
        end
      end

      context 'when there are no classes with `AppConfigurable` module included' do
        it 'returns nothing', :skip_host_class do
          expect(described_class.available_config_attributes).to eq []
        end
      end
    end

    describe '.load_configs', :skip_host_class do
      subject { described_class.load_configs(paths) }

      let(:paths) { %w[./spec/fixtures/app_config1.rb ./spec/fixtures/app_config1] }

      context 'when there are no really malformed files' do
        it 'generally works' do
          subject
          expect(described_class.available_config_attributes.map(&:name)).to eq %i[appconfig1_entry awesome_duplicate_entry awesome_entry]
        end

        context 'when `raise_on_missing` is set to `true`' do
          it 'raises a correct exception' do
            expect_any_instance_of(AppConfig1).to receive(:rails_env).at_least(:once).and_return(ActiveSupport::StringInquirer.new('development')) # rubocop:disable RSpec/AnyInstance
            expect { described_class.load_configs(paths, raise_on_missing: true) }.to raise_error AppConfigurable::Error::RequiredVarMissing, 'AppConfig1.appconfig1_entry'
          end
        end
      end

      context 'when there are malformed files' do
        context 'when incorrect extension' do
          let(:paths) { %w[./spec/fixtures/random_extension.rvm] }

          it 'raises a correct exception' do
            expect { subject }.to raise_error LoadError
          end
        end

        context 'when `AppConfigurable` is not included' do
          let(:paths) { %w[./spec/fixtures/file_without_inclusion.rb] }

          it 'raises a correct exception' do
            expect { subject }.to raise_error NoMethodError
          end
        end
      end
    end

    describe '.missing_required_vars' do
      subject { described_class.missing_required_vars }

      let(:instance) { host_class.instance }
      let(:rails_env) { 'test' }

      before do
        instance.instance_variable_set(:@rails_env, ActiveSupport::StringInquirer.new(rails_env))
      end

      it 'generally works' do
        expect(subject).to eq []
      end

      context 'when there is no default value and `env` is different from `test`' do
        let(:rails_env) { 'development' }

        it 'returns a list of missing attributes' do
          expect(subject).to eq %w[AppConfigTest.attr1 AppConfigTest.attr5]
        end
      end
    end

    describe '.config_attributes' do
      it 'matches declared attribute names' do
        expect(host_class.config_attributes).to eq %i[attr1 attr2 attr3 attr4 attr5]
      end
    end

    describe '.env_value_boolean?' do
      it 'classifies positive and negative values as `boolean`' do
        %w[1 true y yes enabled 0 -1 false n no disabled].each do |value|
          expect(host_class.env_value_boolean?(value)).to be true
        end
      end

      it 'classifies other values as not `boolean`' do
        %w[11 bober -0 +1 nn ä].each do |value|
          expect(host_class.env_value_boolean?(value)).to be false
        end
      end
    end

    describe '.env_value_falsey?' do
      it 'generally works' do
        %w[0 -1 false n no disabled].each do |value|
          expect(host_class.env_value_falsey?(value)).to be true
        end
      end
    end

    describe '.env_value_truthy?' do
      it 'generally works' do
        %w[1 true y yes enabled].each do |value|
          expect(host_class.env_value_truthy?(value)).to be true
        end
      end
    end

    describe '.entry' do
      it 'declares class methods for declared attributes' do
        expect(host_class).to respond_to(:attr1, :attr2, :attr3, :attr4, :attr5)
      end

      it 'declares instance methods for declared attributes' do
        expect(host_class.instance).to respond_to(:attr1, :attr2, :attr3, :attr4, :attr5)
      end
    end

    describe '.instance' do
      it 'returns an instance of the host class' do
        expect(host_class.instance).to be_a host_class
      end
    end
  end

  describe 'instance methods' do
    let(:attrs) { [] }
    let(:instance) { host_class.instance }

    let(:host_class) do
      Class.new do
        include AppConfigurable

        entry :attr1, default: true
      end
    end

    describe '#initialize' do
      let(:instance) { host_class.new(attrs) }

      context 'when attributes are passed' do
        let(:attrs) { { rails_env: 'development' } }

        it 'generally works' do
          expect(instance.rails_env).to eq 'development'
        end
      end

      context 'when no attributes are passed' do
        it 'generally works' do
          expect(instance.rails_env).to eq 'test'
        end
      end
    end

    describe '#env' do
      subject { instance.env }

      context 'when `rails_env` is the same as `Rails.env`' do
        let(:instance) { host_class.new }

        it 'returns `ENV`' do
          expect(subject).to eq current_env
        end
      end

      context 'when `rails_env` is different from `Rails.env`' do
        let(:instance) { host_class.new({ rails_env: 'development' }) }

        it 'parses appropriate `.env.*` files' do
          expect(Dotenv).to receive(:parse).with('.env.development').once.and_return({ super_attribute: 1 })
          expect(subject).to eq({ 'super_attribute' => 1 })
        end
      end
    end

    describe '#rails_env' do
      context 'when no submodule environment is set' do
        it 'returns global environment' do
          expect(instance.rails_env).to eq 'test'
        end
      end

      context 'when submodule environment is set' do
        let(:const_name) { 'AppConfigTest::Hola' }
        let(:host_class) do
          Class.new do
            include AppConfigurable

            entry :attr3, default: true
          end
        end

        it 'returns submodule environment' do
          expect(ENV).to receive(:fetch)
            .with('APPCONFIGTEST_HOLA_ENV', nil)
            .once
            .and_return('development')

          expect(instance.rails_env).to eq 'development'
        end
      end
    end

    describe '#rails_env=' do
      let(:rails_env) { 'staging' }

      before { instance.rails_env = rails_env }

      it 'sets the environment' do
        expect(instance.rails_env).to eq rails_env
      end
    end

    describe '#submodule_env' do
      let(:const_name) { 'AppConfigTest::Hola1' }
      let(:host_class) do
        Class.new do
          include AppConfigurable

          entry :attr3, default: true
        end
      end

      it 'returns the submodule environment' do
        expect(ENV).to receive(:fetch)
          .with('APPCONFIGTEST_HOLA1_ENV', nil)
          .once
          .and_return('some_env_variable_value')

        expect(instance.submodule_env).to be_a ActiveSupport::StringInquirer
        expect(instance.submodule_env).to eq 'some_env_variable_value'
      end
    end

    describe 'private methods' do
      describe '#env_boolean?' do
        subject { instance.send(:env_boolean?, key) }

        let(:key) { '123' }

        context 'when key does not exist' do
          it { is_expected.to be false }
        end

        context 'when key exists' do
          let(:negative_value) { '-1' }
          let(:positive_value) { 'y' }
          let(:value) { positive_value }

          before { allow(instance).to receive(:env).and_return({ key => value }) }

          context 'when value is positive' do
            it { is_expected.to be true }
          end

          context 'when value is negative' do
            let(:value) { negative_value }

            it { is_expected.to be true }
          end
        end
      end

      describe '#env_value' do
        subject { instance.send(:env_value, key) }

        let(:key) { 'val1' }
        let(:value) { 'value' }

        before { allow(instance).to receive(:env).and_return({ key => value }) }

        context 'when value is boolean\'ish' do
          let(:value) { 'true' }

          it 'converts boolean\'ish `string` value to a real boolean value' do
            expect(subject).to be true
          end
        end

        context 'when value is not boolean' do
          it 'returns `nil`' do
            expect(subject).to eq value
          end
        end
      end

      describe '#per_env_value_fallback_for' do
        subject { instance.send(:per_env_value_fallback_for, name, default:, preset:) }

        let(:default) { 'default_value' }
        let(:name) { 'some_name' }
        let(:preset) { 'preset_value' }

        let(:host_class) do
          Class.new do
            include AppConfigurable

            entry :attr1
          end
        end

        context 'when `ENV` value is present' do
          let(:value) { 'env_value' }

          before { allow(instance).to receive(:env).and_return({ name => value }) }

          it 'returns value from `ENV`' do
            expect(subject).to eq value
          end
        end

        context 'when `ENV` value is NOT present, `preset` is present' do
          it 'returns preset value' do
            expect(subject).to eq preset
          end
        end

        context 'when `ENV` value is NOT present, `preset` is NOT present, `default` value is present' do
          let(:preset) { nil }

          context 'when `test` environment' do
            it 'returns default value with `some_super_dummy_` prefix' do
              expect(subject).to eq "some_super_dummy_#{name}"
            end
          end

          context 'when NON-`test` environment' do
            before { instance.instance_variable_set(:@rails_env, ActiveSupport::StringInquirer.new('development')) }

            it 'returns default value' do
              expect(subject).to eq default
            end
          end
        end

        context 'when `ENV` value is NOT present, `preset` is NOT present, `default` value is NOT present' do
          let(:default) { nil }
          let(:preset) { nil }

          context 'when `test` environment' do
            it 'returns default value with `some_super_dummy_` prefix' do
              expect(subject).to eq "some_super_dummy_#{name}"
            end
          end

          context 'when NON-`test` environment' do
            before { instance.instance_variable_set(:@rails_env, ActiveSupport::StringInquirer.new('development')) }

            it 'raises a correct exception' do
              expect do
                subject
              end.to raise_error AppConfigurable::Error::RequiredVarMissing,
                                 "Required ENV variable is missing: #{host_class.name}.#{name}"
            end
          end
        end
      end

      describe '#per_env_default_value_fallback' do
        subject { instance.send(:per_env_default_value_fallback, default) }

        let(:default) { 'default_value' }

        context 'when `test` environment' do
          it 'returns dummy value in a form of a `Proc`' do
            expect(subject).to be_a Proc
            expect(subject.call('dummy')).to eq 'dummy'
          end
        end

        context 'when NON-`test` environment' do
          before { instance.instance_variable_set(:@rails_env, ActiveSupport::StringInquirer.new('development')) }

          it 'returns a default value regardless on Proc\'s argument, wraps `default` argument in `Proc`' do
            expect(subject.call('dummy')).to eq default
          end
        end
      end

      describe '#recalculate_env' do
        subject { instance.send(:recalculate_env) }

        let(:new_env) { { 'some_reference_attribute' => 1 } }

        it 'generally works' do
          instance.env
          instance.instance_variable_set(:@env, new_env)
          expect(instance.env).to eq new_env
          subject
          expect(instance.env).to eq current_env
        end
      end

      describe '#recalculate_values' do
        subject { instance.send(:recalculate_values) }

        let!(:reference_attr1) { instance.attr1 }
        let(:new_attr1) { 'new_attr1' }

        it 'generally works' do
          instance.attr1
          instance.instance_variable_set(:@attr1, new_attr1)
          subject
          expect(instance.attr1).to eq reference_attr1
        end
      end
    end
  end
end
