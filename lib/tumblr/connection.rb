require 'faraday'
require 'forwardable'

# Copied from https://github.com/lostisland/faraday_middleware/blob/e68ff84470705c8a59d9aa99b98cb36101fa10ad/lib/faraday_middleware/request/oauth.rb#L74
# to remove dependency on deprecated faraday middleware gem
module FaradayMiddleware
  class OAuth < Faraday::Middleware
    dependency 'simple_oauth'
    AUTH_HEADER = 'Authorization'
    CONTENT_TYPE = 'Content-Type'
    TYPE_URLENCODED = 'application/x-www-form-urlencoded'
    extend Forwardable
    def_delegator :'Faraday::Utils', :parse_nested_query

    def initialize(app, options)
      super(app)
      @options = options
    end

    def call(env)
      env[:request_headers][AUTH_HEADER] ||= oauth_header(env).to_s if sign_request?(env)
      @app.call(env)
    end

    def oauth_header(env)
      SimpleOAuth::Header.new env[:method],
        env[:url].to_s,
        signature_params(body_params(env)),
        oauth_options(env)
    end

    def sign_request?(env)
      !!env[:request].fetch(:oauth, true)
    end

    def oauth_options(env)
      if (extra = env[:request][:oauth]) && extra.is_a?(Hash) && !extra.empty?
        @options.merge extra
      else
        @options
      end
    end

    def body_params(env)
      if include_body_params?(env)
        if env[:body].respond_to?(:to_str)
          parse_nested_query env[:body]
        else
          env[:body]
        end
      end || {}
    end

    def include_body_params?(env)
      !(type = env[:request_headers][CONTENT_TYPE]) || (type == TYPE_URLENCODED)
    end

    def signature_params(params)
      if params.empty?
        params
      else
        params.reject { |_k, v| v.respond_to?(:content_type) }
      end
    end
  end
end

Faraday::Request::OAuth = FaradayMiddleware::OAuth

Faraday::Request.register_middleware oauth: -> { FaradayMiddleware::OAuth }

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

      Faraday.new(default_options.merge(options)) do |conn|
        data = { :api_host => api_host, :ignore_extra_keys => true}.merge(credentials)
        unless credentials.empty?
          conn.request :oauth, data
        end
        conn.request :multipart
        conn.request :url_encoded
        conn.response :json, :content_type => /\bjson$/
        conn.adapter client
      end
    end
  end
end
