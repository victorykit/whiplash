#!/usr/bin/env ruby
$: << File.expand_path(File.dirname(__FILE__) + '/lib')

require 'logger'
require 'whiplash/server'

use Rack::ShowExceptions
run Whiplash::Server.new
