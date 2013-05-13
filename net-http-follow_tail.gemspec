lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require "net/http/follow_tail/version"

Gem::Specification.new do |s|
  s.name    = 'net-http-follow_tail'
  s.version = Net::HTTP::FollowTail::VERSION

  s.required_ruby_version = ">= 1.9"

  s.summary     = "Like tail -f for the web"
  s.description = "Watch multiple URIs for appended content e.g log files"

  s.authors  = ["Dan Brook"]
  s.email    = 'dan@broquaint.com'
  s.homepage = 'http://github.com/broquaint/net-http-follow_tail'

  s.files        = `git ls-files`.split("\n") - %w(.rvmrc .gitignore)
  s.test_files   = `git ls-files spec`.split("\n")

  s.add_runtime_dependency 'exponential-backoff', '~> 0.0.2'

  s.add_development_dependency 'rake',  '~> 0.9.2'
  s.add_development_dependency 'rspec', '~> 2'
end
