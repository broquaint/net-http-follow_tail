require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |config|
#  config.rcov = true
end

task "push-gem" do
  build_output = %x{gem build net-http-follow_tail.gemspec}
  puts build_output
  
  _, built_gem = *build_output.match(/File: (\S+.gem$)/)

  $stdout.write "Push to rubygems.org? "
  should_push = $stdin.readline() =~ /^y/i

  system "gem push #{built_gem}" unless should_push.nil?
end

task :default => :spec
