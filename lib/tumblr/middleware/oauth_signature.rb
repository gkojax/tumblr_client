# frozen_string_literal: true

require 'simple_oauth'

module Tumblr
  module Middleware
    class OauthSignature < Faraday::Middleware
      def initialize(app, options = {})
        @options = options
        super(app)
      end

      def call(request_env)
        return @app.call(request_env) if @options.empty?

        request_env.request_headers['Authorization'] = oauth_header(request_env)
        @app.call(request_env)
      end

      private

      def oauth_header(request_env)
        SimpleOAuth::Header.new(
          request_env.method,
          request_env.url.to_s,
          {},
          @options
        ).to_s
      end
    end
  end
end
