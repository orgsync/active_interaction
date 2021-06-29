require 'spec_helper'

describe ActiveInteraction::Validation do
  describe '.validate(context, filters, inputs)' do
    let(:inputs) { {} }
    let(:filter) { ActiveInteraction::Filter.new(:name, {}) }
    let(:interaction) do
      name = filter.name
      klass = Class.new(ActiveInteraction::Base) { attr_writer(name) }
      klass.filters[name] = filter
      klass.new
    end
    let(:result) do
      described_class.validate(interaction, interaction.class.filters, inputs)
    end

    context 'no filters are given' do
      let(:interaction) { Class.new(ActiveInteraction::Base).new }

      it 'returns no errors' do
        expect(result).to eql []
      end
    end

    context 'filter.cast returns a value' do
      let(:inputs) { { name: 1 } }

      before do
        allow(filter).to receive(:cast).and_return(1)
      end

      it 'returns no errors' do
        expect(result).to eql []
      end
    end

    context 'filter throws' do
      before do
        allow(filter).to receive(:cast).and_raise(exception)
      end

      context 'InvalidValueError' do
        let(:exception) { ActiveInteraction::InvalidValueError }
        let(:filter) { ActiveInteraction::FloatFilter.new(:name, {}) }

        it 'returns an :invalid_type error' do
          type = I18n.translate(
            "#{ActiveInteraction::Base.i18n_scope}.types.#{filter.class.slug}"
          )

          expect(result).to eql [[filter.name, :invalid_type, { type: type }]]
        end
      end

      context 'MissingValueError' do
        let(:exception) { ActiveInteraction::MissingValueError }

        it 'returns a :missing error' do
          expect(result).to eql [[filter.name, :missing]]
        end
      end

      context 'InvalidNestedValueError' do
        let(:exception) do
          ActiveInteraction::InvalidNestedValueError.new(name, value)
        end
        let(:name) { SecureRandom.hex.to_sym }
        let(:value) { double }

        it 'returns an :invalid_nested error' do
          expect(result).to eql [[
            "#{filter.name}.#{name}",
            I18n.translate(
              :invalid_nested,
              scope: [ActiveInteraction::Base.i18n_scope, :errors, :messages],
              value: value.inspect
            )
          ]]
        end
      end
    end
  end
end
