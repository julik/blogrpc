# A barebones HTTP simulator for using with XML-RPC
class HTTPSimulator
  attr_reader :path
  
  class MockResponse
    attr_reader :status, :headers, :body
    def initialize(s, h, b)
      @status, @headers, @body = s, h, b
    end
    
    def code
      @status
    end
    
    def method_missing(*a)
      puts "KALLED #{a.inspect}"
      super
    end
    
    def get_fields(field)
      self[field]
    end
    
    def [](k)
      @headers[k]
    end
  end
  
  def initialize(test_case, endpoint_url)
    @path = endpoint_url
    @test_case = test_case
    raise "The passed TestCase should support response()" unless @test_case.respond_to?(:response)
    raise "The passed TestCase should support request()" unless @test_case.respond_to?(:request)
  end
  
  def version_1_2; end
  
  def post2(port, request_body, headers)
    @test_case.post(path, params = {}, headers.merge("rack.input" => StringIO.new(request_body)))
    MockResponse.new(@test_case.response.status.to_s, @test_case.response.headers, @test_case.response.body)
  end
  
  def get(path, request_body, headers)
    headers.each_pair{|k,v,| @test_case.request[k] = v }
    @test_case.get path, request_body
    MockResponse.new(@test_case.response.status.to_s, @test_case.response.headers, @test_case.response.body)
  end

  def head(path, request_body, headers)
    headers.each_pair{|k,v,| @test_case.request[k] = v }
    @test_case.head path, request_body
    MockResponse.new(@test_case.response.status.to_s, @test_case.response.headers, @test_case.response.body)
  end
  
  def start(*a)
    yield(*a) if block_given?
  end
  
  def method_missing(m, *args)
    # puts "Called #{m}"
  end
end
