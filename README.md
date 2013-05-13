# Net::HTTP::FollowTail

Fulfils the same role as `tail -f` but for files over HTTP. That is to
say if you have log files (e.g IRC logs) available at a URL you could
follow them with this module.

# Usage

```ruby
require 'net/http/follow_tail'

Net::HTTP::FollowTail.follow(uri: 'http://example.com/irc.log') do |result, tailer|
  puts "Someone on IRC said: ", result.content
end
```

# Interface

If you're desiring of a URI's tail then the simplest way of using this
module is to use the `follow` class method on `Net::HTTP::FollowTail`.
It's first argument should be a hash, or array of hashes, containing
at least `uri` key with a value that's either a `URI::HTTP` instance
or something that would `URI.parse` to one. It also expects a block
which gets executed whenever new data appears at the tail at any of
the URIs. That's demonstrated in the *Usage* example above.

Other data that can be passed in the hash argument(s) are:

- `wait_in_seconds`: How long to wait in seconds between polls.
- `offset`: An offset in `Fixnum` bytes to start at.
- `max_retries`: The number of times to retry in the face of failure
  before giving up.
- `always_callback`: A boolean indicating that the callback should be
  called even the tail request wasn't successful.

The callback is called with two arguments - a
`Net::HTTP::FollowTail::Result` instance and a
`Net::HTTP::FollowTail::Tailer` instance respectively. The former
exposing the result of the most recent tail request at the latter the
current tailing state. By default it is only called when the tail
request was successful.

# Example

This module can be seen put to use at:

https://github.com/broquaint/soup-stash/blob/master/script/keeping-up-with-the-logs

# Author

Dan Brook `<dan@broquaint.com>`
