require 'tumblr/client'
require 'tumblr/config'
require 'tumblr/middleware/oauth_signature'

module Tumblr

  autoload :VERSION, File.join(File.dirname(__FILE__), 'tumblr/version')

  extend Config

  Faraday::Request.register_middleware(oauth_signature: Tumblr::Middleware::OauthSignature)

  class << self
    def new(options={})
      Tumblr::Client.new(options)
    end
  end

end
