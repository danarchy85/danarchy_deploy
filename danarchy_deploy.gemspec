
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "danarchy_deploy/version"

Gem::Specification.new do |spec|
  spec.name          = "danarchy_deploy"
  spec.version       = DanarchyDeploy::VERSION
  spec.authors       = ["Dan James"]
  spec.email         = ["dan@danarchy.me"]

  spec.summary       = %q{Pushes deployments locally or remotely based on a JSON/YAML/CouchDB template.}
  spec.description   = %q{DanarchyDeploy intends to simplify Gentoo Linux (and other distro) deployments down to a single template from an input JSON or YAML file, or from a CouchDB file.}
  spec.homepage      = "https://github.com/danarchy85/danarchy_deploy"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'danarchy_couchdb', '~> 0.1'

  spec.add_development_dependency 'bundler', '~> 2.5'
  spec.add_development_dependency 'rake', '~> 13.0'

  spec.add_runtime_dependency 'mongo', '~> 2.20'
end
