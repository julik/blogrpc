require 'rubygems'
require 'bundler'
require 'minitest'
require 'flexmock'
require 'flexmock/minitest'
require 'net/http'
require_relative 'http_simulator'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'blogrpc'
