# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'win32/loquendo/version'

Gem::Specification.new do |spec|
  spec.name          = "win32-loquendo"
  spec.version       = Win32::Loquendo::VERSION
  spec.authors       = ["Jonas Tingeborn"]
  spec.email         = ["tinjon@gmail.com"]
  spec.description   = %q{Ruby for the Win32 API of Loquendo speech synthesis programs}
  spec.summary       = %q{Ruby API for Loquendo speech synthesis}
  spec.homepage      = "https://github.com/jojje/win32-loquendo"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "ffi"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
