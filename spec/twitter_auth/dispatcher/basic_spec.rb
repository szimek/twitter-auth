require File.dirname(__FILE__) + '/../../spec_helper'

describe TwitterAuth::Dispatcher::Basic do
  before do
    stub_basic!
    @user = Factory.create(:twitter_basic_user, :login => 'twitterman', :password => 'test')
  end

  it 'should require a user as the initialization argument' do
    lambda{TwitterAuth::Dispatcher::Basic.new(nil)}.should raise_error(TwitterAuth::Error, 'Dispatcher must be initialized with a User.')
  end

  it 'should be a child class of a Grackle::Client' do
    TwitterAuth::Dispatcher::Basic.new(@user).should be_a(Grackle::Client)
  end

  it 'should set basic authentication options in Grackle::Client'

  describe '#request' do
    before do
      @dispatcher = TwitterAuth::Dispatcher::Basic.new(@user)
      FakeWeb.register_uri("https://#{@user.login}:#{@user.password}@twitter.com:443/fake.json", :string => {'fake' => true}.to_json)
      FakeWeb.register_uri("https://#{@user.login}:#{@user.password}@twitter.com:443/fake.xml", :string => '<fake>true</fake>')
    end
    
    it 'should automatically parse JSON if valid' do
      @dispatcher.fake?.to_hash.should == {:fake => true}
    end

    it 'should automatically parse XML if valid'

    it "should raise a TwitterAuth::Dispatcher::Error if response code isn't 200 or 401" do
      FakeWeb.register_uri("https://#{@user.login}:#{@user.password}@twitter.com:443/bad_response.json", :string => {'error' => 'bad response'}.to_json, :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response?}.should raise_error(TwitterAuth::Dispatcher::Error)
    end
    
    it 'should raise a TwitterAuth::Dispatcher::Unauthorized on 401' do
      FakeWeb.register_uri("https://#{@user.login}:#{@user.password}@twitter.com:443/unauthenticated_response.xml", :string => "<hash>\n<request>/unauthenticated_response.xml</request>\n<error>bad response</error>\n</hash>", :status => ['401', 'Unauthorized'])
      lambda{@dispatcher.unauthenticated_response.xml?}.should raise_error(TwitterAuth::Dispatcher::Unauthorized, 'The credentials provided did not authorize the user.')
    end

    it 'should set the error message to the JSON message' do
      FakeWeb.register_uri('https://twitter.com:443/bad_response.json', :string => {'error' => 'bad response'}.to_json, :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response?}.should raise_error(TwitterAuth::Dispatcher::Error, 'bad response')
    end

    it 'should set the error message to the XML message' do
      FakeWeb.register_uri("https://#{@user.login}:#{@user.password}@twitter.com:443/bad_response.xml", :string => "<hash>\n<request>/bad_response.xml</request>\n<error>bad response</error>\n</hash>", :status => ['403', 'Forbidden'])
      lambda{@dispatcher.bad_response.xml?}.should raise_error(TwitterAuth::Dispatcher::Error, 'bad response')
    end
  end
end
