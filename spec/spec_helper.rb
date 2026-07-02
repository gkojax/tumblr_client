if ENV['COV'] == '1'
  require 'simplecov'
  SimpleCov.start
end

require 'ostruct'
require 'faraday'
require_relative '../lib/tumblr_client'
