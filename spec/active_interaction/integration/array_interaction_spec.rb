require 'spec_helper'
require 'active_record'
if defined?(JRUBY_VERSION)
  require 'activerecord-jdbcsqlite3-adapter'
else
  require 'sqlite3'
end

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

ActiveRecord::Schema.define do
  create_table(:lists)
  create_table(:elements) { |t| t.column(:list_id, :integer) }
end

class List < ActiveRecord::Base
  has_many :elements
end

class Element < ActiveRecord::Base
  belongs_to :list
end

ArrayInteraction = Class.new(TestInteraction) do
  array :a do
    array
  end
  array :b, default: [[]] do
    array
  end
end

describe ArrayInteraction do
  include_context 'interactions'
  it_behaves_like 'an interaction', :array, -> { [] }
  it_behaves_like 'an interaction', :array, -> { Element.where('1 = 1') }
  it_behaves_like 'an interaction', :array, -> { List.create!.elements }

  context 'with inputs[:a]' do
    let(:a) { [[]] }

    before { inputs[:a] = a }

    it 'returns the correct value for :a' do
      expect(result[:a]).to eql a
    end

    it 'returns the correct value for :b' do
      expect(result[:b]).to eql [[]]
    end

    it 'does not raise an error with an invalid nested value' do
      inputs[:a] = [false]
      expect { outcome }.to_not raise_error
    end
  end

  context 'with an invalid default' do
    it 'raises an error' do
      expect do
        Class.new(ActiveInteraction::Base) do
          array :a, default: Object.new
        end
      end.to raise_error ActiveInteraction::InvalidDefaultError
    end
  end

  context 'with a nested hash' do
    let(:interaction) do
      Class.new(ActiveInteraction::Base) do
        array :foo do
          hash do
            integer :bar
          end
        end
      end
    end

    let(:outcome) { interaction.run(foo: [{ bar: 'baz' }]) }

    it 'sets error with nesting index' do
      expect(outcome.errors).to include(:'foo[0].bar')
    end
  end

  context 'with an invalid default as a proc' do
    it 'does not raise an error' do
      expect do
        Class.new(ActiveInteraction::Base) do
          array :a, default: -> { Object.new }
        end
      end.to_not raise_error
    end
  end

  context 'with an invalid nested default' do
    it 'raises an error' do
      expect do
        Class.new(ActiveInteraction::Base) do
          array :a, default: [Object.new] do
            array
          end
        end
      end.to raise_error ActiveInteraction::InvalidDefaultError
    end
  end
end
