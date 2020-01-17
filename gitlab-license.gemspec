# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gitlab/license/version'

Gem::Specification.new do |spec|
  spec.name          = "gitlab-license"
  spec.version       = Gitlab::License::VERSION
  spec.authors       = ["Douwe Maan"]
  spec.email         = ["douwe@gitlab.com"]

  spec.summary       = %q{gitlab-license helps you generate, verify and enforce software licenses.}
  spec.homepage      = "https://gitlab.com/gitlab-org/gitlab-license"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "byebug"
end
