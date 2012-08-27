require 'rubygems'
require 'bundler'
require 'http_simulator'
require 'test/unit'
require 'flexmock'
require 'flexmock/test_unit'
require 'net/http'

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
