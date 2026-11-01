require 'spec_helper'
require 'tempfile'
require 'webmock/rspec'

describe 'multipart upload' do
  let(:client) do
    Tumblr::Client.new(
      :consumer_key => 'ck', :consumer_secret => 'cs',
      :oauth_token => 'tk', :oauth_token_secret => 'ts',
      :api_scheme => 'https'
    )
  end
  let(:url) { 'https://api.tumblr.com/v2/blog/example.tumblr.com/post' }
  let(:bytes1) { "\xFF\xD8\xFF\x00jpeg-one".b }
  let(:bytes2) { "\x89PNG\x00png-two".b }
  let(:file1) { Tempfile.new(['one', '.jpg'], binmode: true).tap { |f| f.write(bytes1); f.flush } }
  let(:file2) { Tempfile.new(['two', '.png'], binmode: true).tap { |f| f.write(bytes2); f.flush } }
  let(:ok) { { status: 201, body: '{"response": {"id": 1}}', headers: { 'Content-Type' => 'application/json' } } }

  def captured_request(&block)
    captured = nil
    stub_request(:post, url).with { |req| captured = req; true }.to_return(ok)
    block.call
    captured
  end

  def parts_of(req)
    boundary = req.headers['Content-Type'][/boundary=(.+)/, 1]
    req.body.b.split("--#{boundary}").select { |p| p.include?('Content-Disposition') }
  end

  it 'sends an array of file paths as multipart/form-data parts' do
    req = captured_request { client.photo('example.tumblr.com', data: [file1.path, file2.path]) }

    expect(req.headers['Content-Type']).to start_with('multipart/form-data')
    expect(req.headers['Authorization']).to start_with('OAuth ')
    parts = parts_of(req)
    p0 = parts.find { |p| p.include?('name="data[0]"') }
    p1 = parts.find { |p| p.include?('name="data[1]"') }
    expect(p0).to include('Content-Type: image/jpeg').and include(bytes1)
    expect(p1).to include('Content-Type: image/png').and include(bytes2)
  end

  it 'sends a single file path as a multipart part' do
    req = captured_request { client.photo('example.tumblr.com', data: file1.path) }

    expect(req.headers['Content-Type']).to start_with('multipart/form-data')
    part = parts_of(req).find { |p| p.include?('name="data"') }
    expect(part).to include(bytes1)
  end

  it 'passes an existing FilePart through unchanged' do
    part = Faraday::Multipart::FilePart.new(file1.path, 'image/jpeg')
    req = captured_request { client.photo('example.tumblr.com', data: part) }

    expect(parts_of(req).find { |p| p.include?('name="data"') }).to include(bytes1)
  end
end
