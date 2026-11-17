require_relative 'lib/caracal/version'

Gem::Specification.new do |s|
  s.name        = 'caracal'
  s.version     = Caracal::VERSION
  s.authors     = ['Trade Infomatics', 'John Dugan', 'Sprengnetter Real Estate', 'Willem van Kerkhof', 'Kuba Kuzma']
  s.email       = ['jpdugan@gmail.com', 'willem.van-kerkhof@innoq.com']
  s.summary     = 'Fast, professional Microsoft Word (docx) writer for Ruby.'
  s.description = 'Caracal is a pure Ruby Microsoft Word generation library that produces professional quality MSWord documents (docx) using a simple, HTML-style DSL.'
  s.homepage    = 'https://github.com/wvk/caracal'
  s.license     = 'MIT'

  s.metadata = {
    'source_code_uri' => s.homepage,
    'changelog_uri'   => "#{s.homepage}/blob/master/CHANGELOG.md",
  }

  s.required_ruby_version = '>= 3.2'
  s.require_paths         = ['lib']
  s.files                 = Dir.glob(['{lib,spec}/**/*', 'Rakefile', 'README.md', 'CHANGELOG.md', 'Gemfile', 'LICENSE.txt', 'caracal.gemspec'], base: __dir__)

  s.add_dependency 'nokogiri', '>= 1.16.2', '< 2.0'
  s.add_dependency 'ostruct',  '~> 0.6'
  s.add_dependency 'rubyzip',  '>= 1.1.6', '< 4.0'
  s.add_dependency 'tilt',     '>= 2.0'

  s.add_development_dependency 'rake',  '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.0'
end
