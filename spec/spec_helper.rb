require 'caracal'
require 'rspec'
require_relative 'support/ooxml_dump'

RSpec.configure do |config|
  config.mock_with :rspec
  
  config.order = 'random'
end
