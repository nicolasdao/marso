# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'marso/version'

Gem::Specification.new do |spec|
  spec.name          = "marso"
  spec.version       = Marso::VERSION
  spec.authors       = ["Nicolas Dao"]
  spec.email         = ["nicolas@quivers.com"]
  spec.homepage      = ["https://github.com/nicolasdao/marso"]
  spec.summary       = %q{Marso is a lightweight BDD project}
  spec.description   = %q{Marso is the beginning of a small lightweight BDD project. Currently, this is just a very simple code sample that only displays a custom message in green or in red depending on the value of a predicate.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency "colorize"
  spec.add_runtime_dependency "watir-webdriver", "~>0.6.9"
end
