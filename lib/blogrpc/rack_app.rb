# -*- encoding : utf-8 -*-

# An embeddable Rack handler for RPC servers
class BlogRPC::RackApp
  
  # The root URL of the blog
  attr_accessor :blog_url

  # The URL of the blog API endpoint (like /backend.rpc)
  attr_accessor :rpc_endpoint_url
  
  # All the XML-RPC handlers that can respond to the request,
  # if it so happens that you have more than one
  attr_accessor :handlers
  
  def initialize(blog_handler)
    @handlers = [blog_handler]
  end

  def call(env)
    @env = env
    req = Rack::Request.new(env)
    # If the request is a GET return the autodiscovery RSD fragment
    if req.get?
      return endpoint_xml
    else
      return post_request
    end
  end
  
  private
  
  def all_supported_method_names
    method_names = []
    @handlers.map do |h| 
      methods_of_handler = h.get_methods(nil, nil)
      methods_of_handler.each do | m |
        method_names << m[0]
      end
    end
    method_names
  end
  
  def supports_mt?
    all_supported_method_names.grep(/^mt\./).any?
  end
  
  def supports_metaweblog?
    all_supported_method_names.grep(/^metaWeblog\./).any?
  end
  
  def supports_wordpress?
    all_supported_method_names.grep(/^wp\./).any?
  end
  
  # Returns the endpoint information that smart blogging clients
  # can use to detect which APIs you support.
  def endpoint_xml
    b = Builder::XmlMarkup.new
    b.rsd :version => '1.0', :xmlns => "http://archipelago.phrasewise.com/rsd" do; b.service do
      b.engineName "MovableType" # It's better to pose as MT
      b.homePageLink(blog_url)
      b.apis do
        b.api( :name=>"MovableType", :preferred => "true", :apiLink => rpc_endpoint_url, :blogID => 1) if supports_mt?
        b.api( :name=>"MetaWeblog", :apiLink => rpc_endpoint_url, :blogID => 1)  if supports_metaweblog?
        b.api( :name=>"WordPress", :apiLink => rpc_endpoint_url, :blogID => 1)  if supports_wordpress?
      end
    end;end
    [200, {"Content-Length"=> Rack::Utils.bytesize(b.target!), "Content-Type" => 'application/rsd+xml'}, b.target!]
  end
  
  def post_request
    body = begin
      # Ruby's XMLRPC does not love rack.input wrappers,
      # it wants a bona-fide IO. Also, different rack input
      # wrappers work differently (some are better than others),
      # so to protect us from extra grief we will rebuffer everything
      # in a Tempfile
      @temp = Tempfile.new("rxrpc")
      @env['rack.input'].each(&@temp.method(:write))
      @temp.rewind
      s = XMLRPC::BasicServer.new(self)
      # Here we initialize the handlers
      @handlers.each do |handler| 
        # Inject the Rack environment into the handler
        handler.env = @env
        s.add_handler(handler)
      end
      
      # AND PROZESSS!
      s.process(@temp)
    rescue Exception => e # Transform all errors, even LoadError, into a properly formatted XML-RPC fault struct
      # Supports captivity logger by default
      @env["captivity.logger"].fatal([e.message, e.backtrace].join("\n")) if @env['captivity.logger']
      b = Builder::XmlMarkup.new
      b.methodResponse do |b|; b.fault do; b.value do; b.struct do
        b.member {  b.name("faultCode"); b.value { b.int 1 } }
        b.member {  b.name("faultString"); b.value { b.string(format_exception(e)) }}
      end;end;end;end
      b.target!
    ensure
      @temp.close!
    end
    
    [200, {"Content-Length"=> Rack::Utils.bytesize(body), "Content-Type" => 'text/xml; charset=utf-8'}, body]
  end
  
  def format_exception(e)
    first_line = [e.class.to_s, e.message].join(' : ')
    ([first_line] + e.backtrace.to_a).join("\n")
  end
end
