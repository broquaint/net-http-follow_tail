require 'net/http/follow_tail'
require 'spec_helper'

describe Net::HTTP::FollowTail do
  # Not sure if this is appropriate but it does the job.
  before(:each, simple_stub_request: true) do
    stub_request(:head, 'example.com')
      .to_return(headers: { 'Content-Length' => 321 })
    stub_request(:get, 'example.com')
      .with(headers: {'Range' => 'bytes=0-321'})
      .to_return(headers: { 'Content-Length' => 321 })
    Net::HTTP::FollowTail.should_receive(:sleep).with(60)
  end
  
  describe '#follow' do
    it 'calls a block with a result and a tailer', simple_stub_request: true do
      Net::HTTP::FollowTail.follow(uri: 'http://example.com/') do |result, tailer|
        expect(result).to be_an_instance_of(Net::HTTP::FollowTail::Result)
        expect(result.is_success?).to be_true
        tailer.still_following = false
      end
    end

    it 'should accept an Array of options', simple_stub_request: true do
      # Would use multiple items but failing to stub sleep correctly :/
      opts = [{uri: 'http://example.com/'}]
      Net::HTTP::FollowTail.follow(opts) do |result, tailer|
        expect(result).to be_an_instance_of(Net::HTTP::FollowTail::Result)
        expect(result.is_success?).to be_true
        tailer.still_following = false
      end
    end

    it 'raises an error for weird input' do
      expect {
        Net::HTTP::FollowTail.follow(:boom)
      }.to raise_error(ArgumentError)
    end
  end

  describe '#get_tail' do
    it 'should make a request and call a block', simple_stub_request: true do
      a_tailer = Net::HTTP::FollowTail::Tailer.new(uri: 'http://example.com')
      Net::HTTP::FollowTail.get_tail(a_tailer, Proc.new{ |result, tailer|
        expect(tailer).to eql(a_tailer)
        expect(result.is_success?).to be_true
      })
    end

    # Not sure how to test this.
    it 'should retry when an error is received'
  end
end
