# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'whiplash/version'

Gem::Specification.new do |gem|
  gem.name          = "whiplash"
  gem.version       = Whiplash::VERSION
  gem.authors       = ["VictoryKit Team"]
  gem.email         = ["victorykit@thoughtworks.com"]
  gem.description   = %q{UNDER CONSTRUCTION: A multivariate testing framework backed by Redis.}
  gem.summary       = %q{UNDER CONSTRUCTION: A multivariate testing framework backed by Redis.}
  gem.homepage      = "http://act.watchdog.net"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency "redis"
  gem.add_dependency "redis-namespace"
  gem.add_dependency "simple-random"
  gem.add_dependency "sinatra"
  gem.add_dependency "haml"
  gem.add_development_dependency "rspec", ">= 2.0.0"
end
