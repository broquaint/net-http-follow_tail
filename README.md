# Net::HTTP::FollowTail

Fulfils the same role as `tail -f` but for files over HTTP. That is to
say if you have log files (e.g IRC logs) available at a URL you could
follow them with this module.

# Usage

```ruby
require 'net/http/follow_tail'

Net::HTTP::FollowTail.follow(uri: 'http://example.com/irc.log') do |result, tailer|
  puts "Someone on IRC said: ", result.response.body
end
```

# Author

Dan Brook `<dan@broquaint.com>`
