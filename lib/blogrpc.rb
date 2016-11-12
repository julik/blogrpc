module BlogRPC
  VERSION = "1.0.1"
  
  # Generate an RPC Rack application and yield it's only handler class to the passed block.
  # Call rpc(...) on the yielded class to define methods
  def self.generate_endpoint(&blk)
    handler_class = Class.new(BlogRPC::BasicHandler)
    yield(handler_class)
    BlogRPC::RackApp.new(handler_class.new)
  end
end

require File.dirname(__FILE__) + "/blogrpc/rack_app"
require File.dirname(__FILE__) + "/blogrpc/basic_handler"
require File.dirname(__FILE__) + "/blogrpc/sample_handler"