# frozen_string_literal: true

require 'simple_oauth'

module Tumblr
  module Middleware
    class OauthSignature < Faraday::Middleware
      def initialize(app, options = {})
        super(app)
        @oauth_creds = options
      end

      def call(request_env)
        return @app.call(request_env) if @oauth_creds.empty?

        request_env.request_headers['Authorization'] = oauth_header(request_env)
        @app.call(request_env)
      end

      private

      def oauth_header(request_env)
        SimpleOAuth::Header.new(
          request_env.method,
          request_env.url.to_s,
          {},
          @oauth_creds
        ).to_s
      end
    end
  end
end
