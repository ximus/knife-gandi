$:.unshift(File.dirname(__FILE__) + '/lib')
require 'knife-gandi/version'

Gem::Specification.new do |s|
  s.name = 'knife-gandi'
  s.version = KnifeGandi::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE" ]
  s.summary = "Gandi Hosting Support for Chef's Knife Command"
  s.description = s.summary
  s.author = "Maxime Liron"
  s.email = "maximeliron@gmail.com"
  s.homepage = "https://github.com/ximus/knife-gandi"

  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc) + Dir.glob("lib/**/*")
end

