require 'faraday'
require 'forwardable'
require 'simple_oauth'
require_relative 'middleware/oauth_signature'

module Tumblr
  module Connection

    def connection(options={})
      options = options.clone

      default_options = {
        :headers => {
          :accept => 'application/json',
          :user_agent => "tumblr_client/#{Tumblr::VERSION}"
        },
        :url => "#{api_scheme}://#{api_host}/"
      }

      client = Faraday.default_adapter
      creds = { :api_host => api_host, :ignore_extra_keys => true}.merge(credentials)

      Faraday.new(default_options.merge(options)) do |conn|
        unless credentials.empty?
          conn.request Tumblr::Middleware::OauthSignature, creds
        end
        conn.request :url_encoded
        conn.response :json, :content_type => /\bjson$/
        conn.adapter client
      end
    end

  end
end
