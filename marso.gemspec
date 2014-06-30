# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

version = "0.1.%s" % ((Time.now.utc - Time.utc(2014, 5, 28))/60).round
version_file_path = File.join(lib, "marso", "version.rb")
updated_content = nil

# update content
File.open(version_file_path, "rb") do |f|
  content = f.read
  updated_content = content.gsub(/(?<==).*?(?=\n)/, "\"%s\"" % version)
end

# overwrite version.rb with new content
File.open(version_file_path, "w") do |f|
  f.write(updated_content)
end


Gem::Specification.new do |spec|
  spec.name          = "marso"
  spec.version       = version
  spec.authors       = ["Nicolas Dao"]
  spec.email         = ["nicolas@quivers.com"]
  spec.homepage      = "https://github.com/nicolasdao/marso"
  spec.summary       = %q{Marso is a lightweight BDD project}
  spec.description   = %q{Marso is the beginning of a small lightweight BDD project. Currently, this is just a very simple code sample that only displays a custom message in green or in red depending on the value of a predicate.}
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ["marso"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.3"
  spec.add_development_dependency('mocha', '~> 1.0')
  spec.add_development_dependency('turn', '~> 0.9')
  spec.add_runtime_dependency "colorize", "~> 0.7"
  spec.add_runtime_dependency "watir-webdriver", "~> 0.6"
  spec.add_runtime_dependency "eventmachine", "~> 1.0"
end
