# -*- encoding : utf-8 -*-
require 'xmlrpc/server'
require 'fileutils'
require 'builder'

# XML writer with proper escaping. Unfortunately XMLRPC in Ruby
# has issues escaping non-UTF-8 characters, so we need to take care of that.
# The best solution is to make use of the XChar facility from Builder.
c = Class.new(XMLRPC::XMLWriter::Simple) do
  def text(string)
    Builder::XChar.encode(string)
  end
end

# Inject the proper writer into the XML-RPC module. There is no way
# to do that properly so it seems.
begin
  $VERBOSE, yuck = nil, $VERBOSE
  XMLRPC::Config.send(:const_set, :DEFAULT_WRITER, c)
ensure
  $VERBOSE  = yuck
end

# A very simple RPC interface where you can declare methods by calling rpc "methodThis" :in => [:bool], :out => :bool { truth }
# and it creates method_this(some_bool) in Ruby and wires it in
class BlogRPC::BasicHandler < XMLRPC::Service::BasicInterface
  
  # Will contain the Rack application environment
  attr_accessor :env
  
  # The standard initializer for such a service accepts a prefix,
  # but we will override that
  def initialize(prefix = nil)
    @prefix = 'mt'
  end
    
  # Will return a union of all of the methods defined using rpc() in this class
  # and all of it's ancestors.
  def self.rpc_methods_and_signatures
    # Climb up the class chain
    methods_and_signatures_in_ancestor_chain = {}
    ancestors.reverse.each do | ancestor_module |
      in_ancestor = ancestor_module.instance_variable_get('@rpc_methods_and_signatures') || {}
      methods_and_signatures_in_ancestor_chain.merge!(in_ancestor)
    end
    methods_and_signatures_in_ancestor_chain.merge(@rpc_methods_and_signatures || {})
  end
  
  # Pass your XML request here and get the result (the request is the
  # raw HTTP POST body, the way to get to it differs per framework/server)
  #
  #  huge_xml_blob = MiniInterface.new.handle_request(StringIO.new(post_data))
  #
  def handle_request(post_payload)
    s = XMLRPC::BasicServer.new
    s.add_handler self
    s.process(post_payload.respond_to?(:read) ? post_payload : StringIO.new(post_payload) )
  end
  
  # Generate an RPC method uisng a block. Accepts two parameters :in is for the input argument types (should be array)
  # and :out for what it will return.
  # The block defines the method.
  def self.rpc(methName, options, &blk)
    ruby_method = methName.split(/\./).pop.gsub(/([A-Z])/) { |m| '_' + m.downcase }
    define_method(ruby_method, &blk)
    
    options = {:in => []}.merge(options)
    iface, method = methName.split(/\./)
    @rpc_methods_and_signatures ||= {}
    @rpc_methods_and_signatures[ruby_method] = [ methName, "#{options[:out]} #{method}(#{options[:in].join(', ')})" ]
  end
  
  # This is the magic wand. The docs of XMLRPC never explain where the fuck does obj actually ever come from,
  # moreover - here WE are the object (the server sends a nil, anyways). What is important is that this method
  # returns a set of method signatures that XMLRPC will call on our object when processing the request.
  # Delim is omitted since internally we differentiate our namespaced methods anyway (mt. prefix for MovableType
  # and wp. for Wordpress..)
  def get_methods(obj, delim)
    meths = []
    self.class.rpc_methods_and_signatures.each_pair do | ruby_method, details |
      # And bind the method
      meths.unshift [
        details[0], # method name (in XMLRPC terms) including prefix, like "mt.getPost"
        method(ruby_method).to_proc, # the method itself, a callable Proc
        details[1], # signature, like "getPost(string, string, int)"
        (details[2] || "Just a method") # method help
      ]
    end
    meths
  end
  
  # The only default RPC method we declare. Returns the list of supported XML-RPC methods. This implementation can be
  # left in it's default form.
  rpc "mt.supportedMethods", :out => :array do
    self.class.rpc_methods_and_signatures.values.map {|iface| iface[0] }
  end
  
end
