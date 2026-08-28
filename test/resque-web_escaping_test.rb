require 'test_helper'
require 'rack/test'
require 'resque/server'

# Regression tests for HTML escaping in resque-web. Every value below is
# attacker-controlled: either reflected straight off the request, or read back
# out of Redis after being written by anyone able to enqueue a job.
describe "Resque web escaping" do
  include Rack::Test::Methods

  # Breaks out of both a double-quoted attribute and a text node.
  PAYLOAD = %q{"><svg onload=alert(1)>}

  # A literal apostrophe survives a URL path untouched by browsers, so it is
  # what actually reaches PATH_INFO and breaks out of a single-quoted attribute.
  PATH_PAYLOAD = "x'onmouseover='alert(1)"

  def app
    Resque::Server.new
  end

  def default_host
    'localhost'
  end

  # Rack 2 and Rack 3 spell some entities differently (&#x27; vs &#39;), so
  # compare against whatever escape_html the app itself is running.
  def assert_escaped(body, payload = PAYLOAD)
    refute_includes body, payload
    assert_includes body, Rack::Utils.escape_html(payload)
  end

  describe "the request path reflected into links" do
    it "escapes the path in the live poll link" do
      get "/overview/#{PATH_PAYLOAD}"

      assert last_response.ok?, last_response.errors
      assert_escaped last_response.body, PATH_PAYLOAD
    end
  end

  describe "queue names" do
    it "escapes them in the queue listing" do
      Resque.push(PAYLOAD, 'class' => 'SomeJob', 'args' => [])

      get "/queues"

      assert last_response.ok?, last_response.errors
      assert_escaped last_response.body
    end

    it "escapes them on a queue's own page" do
      get "/queues/#{Rack::Utils.escape_path(PAYLOAD)}"

      assert last_response.ok?, last_response.errors
      assert_escaped last_response.body
    end
  end
end
