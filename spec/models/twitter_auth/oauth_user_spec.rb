require File.dirname(__FILE__) + '/../../spec_helper'

describe TwitterAuth::User::Auth::Oauth do
  before do
    stub_oauth!
  end
 
  describe '.identify_or_create_from_access_token' do
    before do
       @token = OAuth::AccessToken.new(TwitterAuth.consumer, 'faketoken', 'fakesecret')
    end

    it 'should accept an OAuth::AccessToken' do
      lambda{ TwitterUser.identify_or_create_from_access_token(@token) }.should_not raise_error(ArgumentError)
    end

    it 'should change the login when the screen_name changes' do
      @user = Factory(:twitter_oauth_user, :id => '123')
      TwitterUser.stub!(:handle_response).and_return({'id' => 123, 'screen_name' => 'dude'})
      TwitterUser.identify_or_create_from_access_token(@token).should == @user.reload
    end

    it 'should accept two strings' do
      lambda{ TwitterUser.identify_or_create_from_access_token('faketoken', 'fakesecret') }.should_not raise_error(ArgumentError)
    end

    it 'should not accept one string' do
      lambda{ TwitterUser.identify_or_create_from_access_token('faketoken') }.should raise_error(ArgumentError, 'Must authenticate with an OAuth::AccessToken or the string access token and secret.')
    end

    it 'should make a call to verify_credentials' do
      # this is in the before, just making it explicit
      TwitterUser.identify_or_create_from_access_token(@token)
    end

    it 'should try to find the user with that id' do
      TwitterUser.should_receive(:find_by_id).once.with('123')
      TwitterUser.identify_or_create_from_access_token(@token)
    end

    it 'should return the user if he/she exists' do
      user = Factory.create(:twitter_oauth_user, :id => '123', :login => 'twitterman')
      user.reload
      TwitterUser.identify_or_create_from_access_token(@token).should == user
    end

    it 'should update the access_token and access_secret for the user if he/she exists' do
      user = Factory.create(:twitter_oauth_user, :id => '123', :login => 'twitterman', :access_token => 'someothertoken', :access_secret => 'someothersecret')
      TwitterUser.identify_or_create_from_access_token(@token)
      user.reload
      user.access_token.should == @token.token
      user.access_secret.should == @token.secret
    end

    it 'should update the user\'s attributes based on the twitter info' do
      user = Factory.create(:twitter_oauth_user, :login => 'twitterman', :name => 'Not Twitter Man')
      TwitterUser.identify_or_create_from_access_token(@token).name.should == 'Twitter Man'
    end

    it 'should create a user if one does not exist' do
      lambda{TwitterUser.identify_or_create_from_access_token(@token)}.should change(TwitterUser, :count).by(1)
    end

    it 'should assign the oauth access token and secret' do
      user = TwitterUser.identify_or_create_from_access_token(@token)
      user.access_token.should == @token.token
      user.access_secret.should == @token.secret
    end
  end

  describe '#token' do
    before do
      @user = Factory.create(:twitter_oauth_user, :access_token => 'token', :access_secret => 'secret')
    end

    it 'should return an AccessToken' do
      @user.token.should be_a(OAuth::AccessToken)
    end

    it "should use the user's access_token and secret" do
      @user.token.token.should == @user.access_token
      @user.token.secret.should == @user.access_secret
    end
  end

  describe '#twitter' do
    before do
      @user = Factory.create(:twitter_oauth_user, :access_token => 'token', :access_secret => 'secret')
    end

    it 'should return a TwitterAuth::Dispatcher::Oauth' do
      @user.twitter.should be_a(TwitterAuth::Dispatcher::Oauth)
    end

    it 'should use my token and secret' do
      @user.twitter.token.should == @user.access_token
      @user.twitter.secret.should == @user.access_secret
    end
  end
end
