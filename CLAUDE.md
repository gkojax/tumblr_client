# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Commands

```bash
# Run all tests
bundle exec rspec spec

# Run a single test file
bundle exec rspec spec/examples/client_spec.rb

# Run a single test
bundle exec rspec spec/examples/client_spec.rb:42

# Build the gem
rake build

# Release (tags, pushes tags, and publishes to rubygems.org)
rake release

# Install locally
gem install pkg/tumblr_client-*.gem
```

## Architecture Overview

**tumblr_client** is an OAuth-authenticated HTTP wrapper for the Tumblr v2 API. It does **not** handle OAuth flow; users must complete the 3-legged OAuth handshake themselves using the Ruby OAuth gem.

### Core Design

The `Tumblr::Client` class acts as a composable interface that includes multiple modules, each grouping related API methods:

- **`Blog`** — Blog info, posts, queues, drafts, followers, settings
- **`User`** — User info, limits, preferences
- **`Post`** — Post creation (text, photo, video, audio, quote, link, chat)
- **`Tagged`** — Search posts by tag
- **`Request`** — Request building and HTTP execution
- **`Connection`** — Faraday setup and credential management

### Request Flow

1. User calls a method on `Client` (e.g., `client.info`)
2. Method is defined in one of the mixin modules (e.g., `User#info`)
3. Method builds request parameters and calls internal `#request` method (from `Request` mixin)
4. `#request` uses the connection (Faraday) to execute the HTTP call with OAuth signing
5. Faraday 2.x middleware (oauth_signature, url_encoded, json) handles OAuth signing and serialization
6. Response is parsed as JSON and returned as a Hash

### Configuration Flow

Global configuration is set via `Tumblr.configure` block:

```ruby
Tumblr.configure do |config|
  config.consumer_key = "..."
  config.consumer_secret = "..."
  config.oauth_token = "..."
  config.oauth_token_secret = "..."
end
```

Per-client overrides are passed to `Tumblr::Client.new`:

```ruby
client = Tumblr::Client.new(consumer_key: "...", oauth_token: "...")
```

## Testing Conventions

- **RSpec** is the test framework
- **WebMock** mocks HTTP responses; real API calls should never be made in tests
- **SimpleCov** tracks coverage
- Test files mirror module names: `spec/examples/{blog,user,post,tagged,client,request}_spec.rb`

When adding API endpoints:

1. Write test first using WebMock to mock the expected request/response
2. Implement the method in the appropriate module (`Blog`, `User`, `Post`, `Tagged`)
3. Method should call `#request` with the HTTP verb and path
4. Add parameters as keyword arguments, building the request params hash

### Example Test Pattern

```ruby
describe Tumblr::Blog do
  let(:client) { Tumblr::Client.new }

  describe '#info' do
    it 'retrieves blog info' do
      stub_request(:get, 'https://api.tumblr.com/v2/blog/example.tumblr.com/info')
        .to_return(status: 200, body: '{"response": {"blog": {...}}}')

      result = client.info('example.tumblr.com')
      expect(result['blog']).not_to be_nil
    end
  end
end
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/tumblr/client.rb` | Main class; includes all mixin modules |
| `lib/tumblr/config.rb` | Global configuration management |
| `lib/tumblr/connection.rb` | Faraday HTTP setup with OAuth middleware |
| `lib/tumblr/request.rb` | Request execution; internal request building and response handling |
| `lib/tumblr/{blog,user,post,tagged}.rb` | API endpoint methods grouped by domain |
| `lib/tumblr/helpers.rb` | Shared utility functions |
| `spec/spec_helper.rb` | RSpec configuration and shared setup |
| `spec/examples/*_spec.rb` | API method tests using WebMock |

## Important Notes

- **Git Config**: Add `.claude/` to `.gitignore` to exclude local Claude Code settings from commits.
- **OAuth Handling**: This gem does not implement the 3-legged OAuth flow. Consumers must use the Ruby OAuth gem to obtain tokens and then configure this client.
- **Faraday Adapter**: Users can specify a custom Faraday HTTP adapter when creating a client: `Tumblr::Client.new(client: :httpclient)`
- **API Host**: Default is `api.tumblr.com`. Can be overridden via `TUMBLR_API_HOST` environment variable or per-client option.
- **Ruby Versions**: Supports Ruby 1.9.x through 3.x (CI tests 2.6, 2.7, 3.0)

## Adding New API Endpoints

Reference: https://www.tumblr.com/docs/en/api/v2 (official) and https://github.com/tumblr/docs (GitHub repository)

When wrapping new Tumblr API endpoints:

1. Determine the domain: Blog, User, Post, or create a new module if needed
2. Add the method to the appropriate module in `lib/tumblr/`
3. Use `#request(method, path, params)` to execute HTTP calls
4. Add corresponding test in `spec/examples/` with WebMock stubs
5. Verify coverage remains >80% with SimpleCov
