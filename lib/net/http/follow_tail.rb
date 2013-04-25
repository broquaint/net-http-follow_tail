require 'net/http'
require 'uri'
require 'exponential_backoff'

class Net::HTTP::FollowTail
  class Result
    attr_reader :state, :method, :response
    def initialize(args)
      @state    = args[:state]
      @method   = args[:method]
      @response = args[:response]
    end

    def has_response?
      not @response.nil?
    end
    
    def is_success?
      @state == :success
    end
    def is_error?
      @state == :error
    end

    def offset
      response.content_length
    end
  end

  class Tailer  
    attr_reader :uri, :offset, :wait_in_seconds, :exponential_backoff,
                :max_retries, :retries_so_far,
                :verbose
    attr_writer :still_following
    def initialize(opts)
      raise ArgumentError, 'A :uri must be passed to the constructor' unless opts[:uri]

      @uri    = opts[:uri].kind_of?(URI::Generic) ? opts[:uri] : URI.parse(opts[:uri])
      @offset = opts[:offset] || 0

      @wait_in_seconds = opts[:wait] || 60

      @max_retries    = opts[:max_retries] || 5
      @retries_so_far = 0

      @exponential_backoff = get_backoff_list

      @still_following = true

      @verbose = opts[:verbose] || false
    end

    def still_following?
      @still_following
    end

    # This and regular_wait need new names!
    def error_wait
      @retries_so_far += 1
      if exponential_backoff.length > 1
        exponential_backoff.shift
      else
        still_following = false
        exponential_backoff.first
      end
    end
    def regular_wait
      @exponential_backoff = get_backoff_list
      @retries_so_far      = 0
      wait_in_seconds
    end

    def update_offset(offset_increment)
      @offset = offset_increment
    end

    def head_request
      http = Net::HTTP.new(uri.host, uri.port)
      http.request( Net::HTTP::Head.new(uri.to_s) )
    end

    def get_request(size_now)
      http = Net::HTTP.new(uri.host, uri.port)
      req  = Net::HTTP::Get.new(uri.to_s)
      req.initialize_http_header('Range' => "bytes=#{offset}-#{size_now}")
      http.request(req)
    end

    def tail
      begin
        head_response = head_request
      rescue Timeout::Error, SocketError, EOFError
        return Result.new(state: :error, method: :head)
      end
      # TODO head_resonse.value
      
      size_now = head_response.content_length
      if size_now == offset
        return Result.new(state: :no_change, method: :head, response: head_response)
      end

      begin
        get_response = get_request(size_now)
      rescue Timeout::Error, SocketError, EOFError
        return Result.new(state: :error, method: :get)
      end

      update_offset get_response.content_length

      # yield get_response, offset_for(uri)
      return Result.new(state: :success, method: :get, response: get_response)
    end

    private
    
    def get_backoff_list
      ExponentialBackoff.new(
        wait_in_seconds, wait_in_seconds ** 2
      ).intervals_for(0 .. max_retries)
    end
  end

  def self.follow(opts, &block)
    tailers = normalize_options(opts).collect{|o| Tailer.new(o)}

    while tailers.any? {|t| t.still_following?}
      for tailer in tailers.select{|t| t.still_following?}
        get_tail tailer, block
      end
    end
  end

  def self.normalize_options(opts)
    return [opts] if opts.is_a?(Hash)

    raise ArgumentError, "Expected a Hash or Array not a #{opts}" unless opts.is_a? Array

    opts
  end

  def self.get_tail(tailer, block)
    result = tailer.tail
    if result.is_error?
      sleep tailer.error_wait
      # Hope max_retries isn't too large ahem.
      get_tail tailer, block if tailer.retries_so_far <= tailer.max_retries
    else
      block.call(result, tailer) if result.is_success?
      # Everyone loves $stdout amirite?
      puts "[#{Time.now}] Now at #{tailer.offset} for #{tailer.uri}" if tailer.verbose
      sleep tailer.regular_wait
    end
  end
end
