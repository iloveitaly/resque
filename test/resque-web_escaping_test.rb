require 'test_helper'
require 'rack/test'
require 'resque/server'

# Regression tests for HTML escaping in resque-web. Every value below is
# attacker-controlled: either reflected straight off the request, or read back
# out of Redis after being written by anyone able to enqueue a job.
describe "Resque web escaping" do
  include Rack::Test::Methods

  def app
    Resque::Server.new
  end

  def default_host
    'localhost'
  end

  # A literal apostrophe survives a URL path untouched by browsers, so it is
  # what actually reaches PATH_INFO and breaks out of a single-quoted attribute.
  PATH_PAYLOAD = "x'onmouseover='alert(1)"

  describe "the request path reflected into links" do
    it "escapes the path in the live poll link" do
      get "/overview/#{PATH_PAYLOAD}"

      assert last_response.ok?, last_response.errors
      refute_includes last_response.body, PATH_PAYLOAD
      # Rack 2 and Rack 3 spell some entities differently (&#x27; vs &#39;), so
      # compare against whatever escape_html the app itself is running.
      assert_includes last_response.body, Rack::Utils.escape_html(PATH_PAYLOAD)
    end
  end
end
