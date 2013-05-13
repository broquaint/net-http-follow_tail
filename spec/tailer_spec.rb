require 'net/http/follow_tail'
require 'spec_helper'

describe Net::HTTP::FollowTail::Tailer do
  let(:example_uri)   { 'http://example.com/' }
  let(:example_host)  { 'example.com' }
  let(:simple_tailer) { Net::HTTP::FollowTail::Tailer.new(uri: example_uri) }
  let(:default_wait)  { 60 }

  describe '#new' do
    it 'has sensible defaults' do
      tailer = simple_tailer
      expect(tailer.uri).to be_an_instance_of(URI::HTTP)
      expect(tailer.offset).to eq(0)
      expect(tailer.wait_in_seconds).to eq(default_wait)
      expect(tailer.max_retries).to eq(5)
      expect(tailer.retries_so_far).to eq(0)
    end

    it 'requires a uri to be specified' do
      expect {
        Net::HTTP::FollowTail::Tailer.new
      }.to raise_error(Reindeer::Meta::Attribute::AttributeError)
    end

    it 'accepts a URI instance' do
      uri = URI.parse(example_uri)
      tailer = Net::HTTP::FollowTail::Tailer.new(uri: uri)
      expect(tailer.uri).to eql(uri)
    end

    it 'accepts offset, wait & max_retries options' do
      tailer = Net::HTTP::FollowTail::Tailer.new(
        uri: example_uri,
        offset: 1234,
        wait_in_seconds: 20,
        max_retries: 2,
      )
      expect(tailer.uri).to be_an_instance_of(URI::HTTP)
      expect(tailer.offset).to eq(1234)
      expect(tailer.wait_in_seconds).to eq(20)
      expect(tailer.max_retries).to eq(2)
    end
  end

  describe '.regular_wait' do
    it 'always returns wait_in_seconds' do
      tailer = Net::HTTP::FollowTail::Tailer.new(
        uri: example_uri,
        wait_in_seconds: 66,
      )

      expect(tailer.wait_in_seconds).to eq(66)
    end
  end

  describe '.error_wait' do
    it 'munges state appropriately' do
      tailer = simple_tailer

      expect(tailer.wait_in_seconds).to eq(default_wait)
      expect(tailer.error_wait).to eq(default_wait)
      expect(tailer.error_wait).to be > default_wait
    end
  end

  describe '.head_request' do
    it 'provides a response' do
      stub_request :head, "example.com"
      expect(simple_tailer.head_request).to be_an_instance_of(Net::HTTPOK)
    end
  end

  describe '.get_request' do
    it 'should make ranged requests' do
      stub_request(:get, example_host).with(headers: {'Range' => 'bytes=0-200'})
      expect(simple_tailer.get_request(200)).to be_an_instance_of(Net::HTTPOK)
    end
    
    it 'makes range requests against an offset' do
      tailer = simple_tailer
      tailer.update_offset 200
      stub_request(:get, example_host).with(headers: {'Range' => 'bytes=200-400'})
      expect(tailer.get_request(400)).to be_an_instance_of(Net::HTTPOK)
    end
  end

  describe '.tail' do
    it 'returns a result object' do
      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 321 })
      stub_request(:get, example_host)
        .with(headers: {'Range' => 'bytes=0-321'})
        .to_return(headers: { 'Content-Length' => 321 })

      result = simple_tailer.tail
      expect(result).to be_an_instance_of(Net::HTTP::FollowTail::Result)
      expect(result.is_success?).to be_true
    end

    it 'updates offset state with multiple tail calls' do
      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 5 })
      stub_request(:get, example_host)
        .with(headers: {'Range' => 'bytes=0-5'})
        .to_return(headers: { 'Content-Length' => 5 })

      tailer = simple_tailer
      tailer.tail

      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 10 })
      stub_request(:get, example_host)
        .with(headers: {'Range' => 'bytes=5-10'})
        .to_return(headers: { 'Content-Length' => 5 })

      result = tailer.tail
      expect(result).to be_an_instance_of(Net::HTTP::FollowTail::Result)
      expect(result.is_success?).to be_true
      expect(result.method).to be(:get)
      expect(tailer.offset).to eq(10)

      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 15 })
      stub_request(:get, example_host)
        .with(headers: {'Range' => 'bytes=10-15'})
        .to_return(headers: { 'Content-Length' => 5 })

      result = tailer.tail
      expect(tailer.offset).to eq(15)
    end

    it 'correctly updates against existing offset' do
      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 66 })
      stub_request(:get, example_host)
        .with(headers: {'Range' => 'bytes=50-66'})
        .to_return(headers: { 'Content-Length' => 16 })

      tailer = Net::HTTP::FollowTail::Tailer.new(uri: example_uri, offset: 50)
      tailer.tail
      expect(tailer.offset).to eq(66)
    end

    it 'to handle HEAD errors' do
      stub_request(:head, example_host).to_timeout

      result = simple_tailer.tail
      expect(result.is_error?).to be_true
      expect(result.method).to be(:head)
      expect(result.has_response?).to be_false
      expect(result.error).to be_an_instance_of(Timeout::Error)
    end

    it 'to handle GET errors' do
      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 10 })
      stub_request(:get, example_host).to_timeout

      result = simple_tailer.tail
      expect(result.is_error?).to be_true
      expect(result.method).to be(:get)
      expect(result.has_response?).to be_false
    end

    it 'returns a no change Result when appropriate' do
      stub_request(:head, example_host)
        .to_return(headers: { 'Content-Length' => 25 })

      tailer = Net::HTTP::FollowTail::Tailer.new(
        uri: example_uri,
        offset: 25
      )

      result = tailer.tail
      expect(result.state).to eq(:no_change)
      expect(result.method).to eq(:head)
      expect(result.has_response?).to be_true
      expect(result.is_success?).to be_false
      expect(result.is_error?).to be_false
    end
  end
end
