require_relative 'helper'
require 'xmlrpc/client'
require 'rack/test'

class TestRackHandler < Minitest::Test
  include Rack::Test::Methods
  
  def response
    last_response
  end
  
  def app
    BlogRPC.generate_endpoint do | handler |
      handler.rpc "mt.getPostCategories", :in => [:int, :string, :string], :out => :array do | postid, user, pw |
        [{categoryId: 1, categoryName: "Awesome posts"}]
      end
      
      handler.rpc "junk.processJunk", :in => [], :out => :boolean do
        true
      end
    end
  end
  
  def test_method_table
    # Make sure Net::HTTP makes that request into the testcase instead of the Interwebs
    http = HTTPSimulator.new(self, "/rpc.xml")
    flexmock(Net::HTTP) { |mock| mock.should_receive(:new).once.and_return(http) }
    client = XMLRPC::Client.new("localhost", "/rpc.xml", 80)
    
    methods_via_rpc = client.call("mt.supportedMethods")
    assert_equal %w( mt.supportedMethods mt.getPostCategories junk.processJunk ), methods_via_rpc
    assert_equal "text/xml; charset=utf-8", last_response['Content-Type']
  end
  
  def test_get_returns_rsd
    get '/rpc.xml'
    assert_equal "application/rsd+xml", last_response['Content-Type']
    assert last_response.body.include?('api name="MovableType" preferred="true"')
  end
end
