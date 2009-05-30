require File.dirname(__FILE__) + '/../../spec_helper'

describe TwitterAuth::Dispatcher::Oauth do
  before do
    stub_oauth!
    @user = Factory.create(:twitter_oauth_user, :access_token => 'token', :access_secret => 'secret')
  end

  it 'should require initialization of an OauthUser' do
    lambda{TwitterAuth::Dispatcher::Oauth.new(nil)}.should raise_error(TwitterAuth::Error, 'Dispatcher must be initialized with a User.')
  end

  it 'should be a child class of Grackle::Client' do
    TwitterAuth::Dispatcher::Oauth.new(@user).should be_a(Grackle::Client)
  end

  it 'should set oauth authentication options in Grackle::Client'

  describe '#request' do
    before do
      @dispatcher = TwitterAuth::Dispatcher::Oauth.new(@user)
      FakeWeb.register_uri(:get, 'https://twitter.com:443/fake.json', :string => {'fake' => true}.to_json)
      FakeWeb.register_uri(:get, 'https://twitter.com:443/fake.xml', :string => "<fake>true</fake>")
    end
    
    it 'should automatically parse JSON if valid' do
      @dispatcher.fake?.to_hash.should == {:fake => true}
    end

    it 'should automatically parse XML if valid'

    it "should raise a TwitterAuth::Dispatcher::Error if response code isn't 200 or 401" do
      FakeWeb.register_uri('https://twitter.com:443/bad_response.json', :string => {'error' => 'bad response'}.to_json, :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response?}.should raise_error(TwitterAuth::Dispatcher::Error)
    end

    it 'should raise a TwitterAuth::Dispatcher::Unauthorized on 401' do
      FakeWeb.register_uri('https://twitter.com:443/unauthenticated_response.xml', :string => "<hash>\n<request>/unauthenticated_response.xml</request>\n<error>bad response</error>\n</hash>", :status => ['401', 'Unauthorized'])
      lambda{@dispatcher.unauthenticated_response.xml?}.should raise_error(TwitterAuth::Dispatcher::Unauthorized)
    end

    it 'should set the error message to the JSON message' do
      FakeWeb.register_uri('https://twitter.com:443/bad_response.json', :string => {'error' => 'bad response'}.to_json, :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response?}.should raise_error(TwitterAuth::Dispatcher::Error, 'bad response')
    end

    it 'should set the error message to the XML message' do
      FakeWeb.register_uri('https://twitter.com:443/bad_response.xml', :string => "<hash>\n<request>/bad_response.xml</request>\n<error>bad response</error>\n</hash>", :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response.xml?}.should raise_error(TwitterAuth::Dispatcher::Error, 'bad response')
    end
  end
end
