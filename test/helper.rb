require 'rubygems'
require 'bundler'
require 'http_simulator'
require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'
require 'net/http'

# http://redmine.ruby-lang.org/issues/4882
# https://github.com/jimweirich/flexmock/issues/4
# https://github.com/julik/flexmock/commit/4acea00677e7b558bd564ec7c7630f0b27d368ca
class FlexMock::PartialMockProxy
  def singleton?(method_name)
    @obj.singleton_methods.include?(method_name.to_s)
  end
end

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'blogrpc'

class Test::Unit::TestCase
end
