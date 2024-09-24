# frozen_string_literal: true

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

  # Internal: The base class for middleware that parses responses.
  class ResponseMiddleware < Faraday::Middleware
    CONTENT_TYPE = 'Content-Type'

    class << self
      attr_accessor :parser
    end

    # Store a Proc that receives the body and returns the parsed result.
    def self.define_parser(parser = nil, &block)
      @parser = parser ||
                block  ||
                raise(ArgumentError, 'Define parser with a block')
    end

    def self.inherited(subclass)
      super
      subclass.load_error = load_error if subclass.respond_to? :load_error=
      subclass.parser = parser
    end

    def initialize(app = nil, options = {})
      super(app)
      @options = options
      @parser_options = options[:parser_options]
      @content_types = Array(options[:content_type])
    end

    def call(environment)
      @app.call(environment).on_complete do |env|
        process_response(env) if process_response_type?(response_type(env)) && parse_response?(env)
      end
    end

    def process_response(env)
      env[:raw_body] = env[:body] if preserve_raw?(env)
      env[:body] = parse(env[:body])
    rescue Faraday::ParsingError => e
      raise Faraday::ParsingError.new(e.wrapped_exception, env[:response])
    end

    # Parse the response body.
    #
    # Instead of overriding this method, consider using `define_parser`.
    def parse(body)
      if self.class.parser
        begin
          self.class.parser.call(body, @parser_options)
        rescue StandardError, SyntaxError => e
          raise e if e.is_a?(SyntaxError) &&
                     e.class.name != 'Psych::SyntaxError'

          raise Faraday::ParsingError, e
        end
      else
        body
      end
    end

    def response_type(env)
      type = env[:response_headers][CONTENT_TYPE].to_s
      type = type.split(';', 2).first if type.index(';')
      type
    end

    def process_response_type?(type)
      @content_types.empty? || @content_types.any? do |pattern|
        pattern.is_a?(Regexp) ? type =~ pattern : type == pattern
      end
    end

    def parse_response?(env)
      env[:body].respond_to? :to_str
    end

    def preserve_raw?(env)
      env[:request].fetch(:preserve_raw, @options[:preserve_raw])
    end
  end

  # DRAGONS
  module OptionsExtension
    attr_accessor :preserve_raw

    def to_hash
      super.update(preserve_raw: preserve_raw)
    end

    def each
      return to_enum(:each) unless block_given?

      super
      yield :preserve_raw, preserve_raw
    end

    def fetch(key, *args)
      if key == :preserve_raw
        value = __send__(key)
        value.nil? ? args.fetch(0) : value
      else
        super
      end
    end
  end

  if defined?(Faraday::RequestOptions)
    begin
      Faraday::RequestOptions.from(preserve_raw: true)
    rescue NoMethodError
      Faraday::RequestOptions.include OptionsExtension
    end
  end

  # Public: Parse response bodies as JSON.
  class ParseJson < ResponseMiddleware
    dependency do
      require 'json' unless defined?(::JSON)
    end

    define_parser do |body, parser_options|
      ::JSON.parse(body, parser_options || {}) unless body.strip.empty?
    end

    # Public: Override the content-type of the response with "application/json"
    # if the response body looks like it might be JSON, i.e. starts with an
    # open bracket.
    #
    # This is to fix responses from certain API providers that insist on serving
    # JSON with wrong MIME-types such as "text/javascript".
    class MimeTypeFix < ResponseMiddleware
      MIME_TYPE = 'application/json'

      def process_response(env)
        old_type = env[:response_headers][CONTENT_TYPE].to_s
        new_type = MIME_TYPE.dup
        new_type << ';' << old_type.split(';', 2).last if old_type.index(';')
        env[:response_headers][CONTENT_TYPE] = new_type
      end

      BRACKETS = %w-[ {-.freeze
      WHITESPACE = [' ', "\n", "\r", "\t"].freeze

      def parse_response?(env)
        super && BRACKETS.include?(first_char(env[:body]))
      end

      def first_char(body)
        idx = -1
        char = body[idx += 1]
        char = body[idx += 1] while char && WHITESPACE.include?(char)
        char
      end
    end
  end

end

Faraday::Request::OAuth = FaradayMiddleware::OAuth
Faraday::Response::ParseJson = FaradayMiddleware::ParseJson # deprecated alias

Faraday::Request.register_middleware oauth: -> { FaradayMiddleware::OAuth }
Faraday::Response.register_middleware json: -> { FaradayMiddleware::ParseJson }

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
