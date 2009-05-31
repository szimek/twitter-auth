require File.dirname(__FILE__) + '/../../spec_helper'

describe TwitterAuth::SessionsController do
  integrate_views

  describe 'routes' do
    it 'should route /twitter/session/new to TwitterAuth::SessionsController#new' do
      params_from(:get, '/twitter/session/new').should == {:controller => 'twitter_auth/sessions', :action => 'new'}
    end

    it 'should route /twitter/login to TwitterAuth::SessionsController#new' do
      params_from(:get, '/twitter/login').should == {:controller => 'twitter_auth/sessions', :action => 'new'}
    end

    it 'should route /twitter/logout to TwitterAuth::SessionsController#destroy' do
      params_from(:get, '/twitter/logout').should == {:controller => 'twitter_auth/sessions', :action => 'destroy'}
    end

    it 'should route DELETE /twitter/session to TwitterAuth::SessionsController#destroy' do
      params_from(:delete, '/twitter/session').should == {:controller => 'twitter_auth/sessions', :action => 'destroy'}
    end

    it 'should route /twitter/oauth_callback to TwitterAuth::SessionsController#oauth_callback' do
      params_from(:get, '/twitter/oauth_callback').should == {:controller => 'twitter_auth/sessions', :action => 'oauth_callback'}
    end

    it 'should route POST /twitter/session to TwitterAuth::SessionsController#create' do
      params_from(:post, '/twitter/session').should == {:controller => 'twitter_auth/sessions', :action => 'create'}
    end
  end

  describe 'with OAuth strategy' do
    before do
      stub_oauth!
    end

    describe '#new' do
      it 'should retrieve a request token' do
        get :new
        assigns[:request_token].token.should == 'faketoken'
        assigns[:request_token].secret.should == 'faketokensecret'
      end

      it 'should set session variables for the request token' do
        get :new
        session[:request_token].should == 'faketoken'
        session[:request_token_secret].should == 'faketokensecret'
      end

      it 'should redirect to the oauth authorization url' do
        get :new
        response.should redirect_to('https://twitter.com/oauth/authorize?oauth_token=faketoken')
      end

      it 'should redirect to the oauth_callback if one is specified' do
        TwitterAuth.stub!(:oauth_callback).and_return('http://localhost:3000/development')
        TwitterAuth.stub!(:oauth_callback?).and_return(true)

        get :new
        response.should redirect_to('https://twitter.com/oauth/authorize?oauth_token=faketoken&oauth_callback=' + CGI.escape(TwitterAuth.oauth_callback))
      end
    end

    describe '#oauth_callback' do
      describe 'with no session info' do
        it 'should set the flash[:error]' do
          get :oauth_callback, :oauth_token => 'faketoken'
          flash[:error].should == 'No authentication information was found in the session. Please try again.'
        end

        it 'should redirect to "/" by default' do
          get :oauth_callback, :oauth_token => 'faketoken'
          response.should redirect_to('/')
        end

        it 'should call authentication_failed' do
          TwitterUser.stub!(:identify_or_create_from_access_token).and_return(Factory.create(:twitter_oauth_user, :id => 123))
          controller.should_receive(:authentication_failed).any_number_of_times
          get :oauth_callback, :oauth_token => 'faketoken'
        end
      end

      describe 'with proper info' do
        before do
          @twitter_user = Factory.create(:twitter_oauth_user, :id => '123')
          @time = Time.now
          @remember_token = ActiveSupport::SecureRandom.hex(10)

          Time.stub!(:now).and_return(@time)
          ActiveSupport::SecureRandom.stub!(:hex).and_return(@remember_token)

          request.session[:request_token] = 'faketoken'
          request.session[:request_token_secret] = 'faketokensecret'
        end

        describe 'building the access token' do
          before do
            get :oauth_callback, :oauth_token => 'faketoken'
          end

          it 'should rebuild the request token' do
            correct_token =  OAuth::RequestToken.new(TwitterAuth.consumer,'faketoken','faketokensecret')

            %w(token secret).each do |att|
              assigns[:request_token].send(att).should == correct_token.send(att)
            end
          end

          it 'should exchange the request token for an access token' do
            assigns[:access_token].should be_a(OAuth::AccessToken)
            assigns[:access_token].token.should == 'fakeaccesstoken'
            assigns[:access_token].secret.should == 'fakeaccesstokensecret'
          end

          it 'should wipe the request token after exchange' do
            session[:request_token].should be_nil
            session[:request_token_secret].should be_nil
          end
        end

        describe 'identifying the twitter user' do
          before do
            get :oauth_callback, :oauth_token => 'faketoken'
          end

          it "should find the twitter user" do
            assigns[:twitter_user].should == @twitter_user
          end

          it "should call remember me" do
            @twitter_user.reload
            @twitter_user.remember_token.should == @remember_token
          end

          it "should set a cookie" do
            cookies[:remember_token].should == @remember_token
          end
        end

        describe 'creating the twitter user' do          
          before do
            # TODO remove (or better - don't create) TwitterUser and User
            get :oauth_callback, :oauth_token => 'faketoken'
          end

          it 'should create the twitter user'
          it "should call remember me"
          it "should set a cookie"
        end

        describe 'when user is already logged in using other auth system' do
          before do
            @user = Factory.create(:user)
          end

          describe 'and has logged in previously with his twitter account' do
            before do
              request.session[:user_id] = @user.id
              get :oauth_callback, :oauth_token => 'faketoken'
            end

            it 'should find twitter user' do
              assigns[:twitter_user].should == @twitter_user
            end

            it 'should assign found twitter_user to logged in user' do
              assigns[:user].twitter_id.should == assigns[:twitter_user].id
            end

            it 'should not change session[:user_id]' do
              session[:user_id].should == @user.id
            end

            it 'should destroy old user' do
              User.exists?(@twitter_user.user).should be_false
            end
          end

          describe 'and has never logged in previously with his twitter account' do
            # TODO remove (or better - don't create) TwitterUser and User
            it 'should create twitter user'
            it 'should assign created twitter_user to logged in user'
            it 'should not change session[:user_id]'
          end
        end

        describe 'when user is logged out' do
          describe 'and has logged in previously with his twitter account' do
            before do
              get :oauth_callback, :oauth_token => 'faketoken'
            end

            it "should log user in" do
              session[:user_id].should == @twitter_user.user.id
            end
          end
          describe 'and has never logged in previously with his twitter account' do
            # TODO remove (or better - don't create) TwitterUser and User
            it "should create new user"
            it "should log user in"
          end
        end

        describe "when OAuth doesn't work" do
          before do
            request.session[:request_token] = 'faketoken'
            request.session[:request_token_secret] = 'faketokensecret'
            @request_token =  OAuth::RequestToken.new(TwitterAuth.consumer, session[:request_token], session[:request_token_secret])
            OAuth::RequestToken.stub!(:new).and_return(@request_token)
          end

          it 'should call authentication_failed when it gets a 401 from OAuth' do
            @request_token.stub!(:get_access_token).and_raise(Net::HTTPServerException.new('401 "Unauthorized"', '401 "Unauthorized"'))
            controller.should_receive(:authentication_failed).with('This authentication request is no longer valid. Please try again.')
            # the should raise_error is hacky because of the expectation
            # stubbing the proper behavior :-(
            lambda{get :oauth_callback, :oauth_token => 'faketoken'}.should raise_error(ActionView::MissingTemplate)
          end

          it 'should call authentication_failed when it gets a different HTTPServerException' do
            @request_token.stub!(:get_access_token).and_raise(Net::HTTPServerException.new('404 "Not Found"', '404 "Not Found"'))
            controller.should_receive(:authentication_failed).with('There was a problem trying to authenticate you. Please try again.')
            lambda{get :oauth_callback, :oauth_token => 'faketoken'}.should raise_error(ActionView::MissingTemplate)
          end
        end
      end
    end
  end

  describe 'with Basic strategy' do
    before do
      stub_basic!
    end

    describe '#new' do
      it 'should render the new action' do
        get :new
        response.should render_template('twitter_auth/sessions/new')
      end

      it 'should render the login form' do
        get :new
        response.should have_tag('form[action=/twitter/session][id=login_form][method=post]')
      end

      describe '#create' do
        before do
          @user = Factory.create(:twitter_basic_user, :id => '123')
        end

        it 'should call logout_keeping_session! to remove session info' do
          TwitterUser.stub(:authenticate).and_return(false)
          controller.should_receive(:logout_keeping_session!)
          post :create
        end

        it 'should try to authenticate the user' do
          TwitterUser.should_receive(:authenticate)
          post :create
        end

        it 'should call authentication_failed on authenticate failure' do
          TwitterUser.should_receive(:authenticate).and_return(nil)
          post :create, :login => 'wrong', :password => 'false'
          response.should redirect_to('/login')
        end

        it 'should call authentication_succeeded on authentication success' do
          TwitterUser.should_receive(:authenticate).and_return(@user)
          post :create, :login => 'twitterman', :password => 'cool'
          response.should redirect_to('/')
          flash[:notice].should_not be_blank
        end
      end
    end
  end

  describe '#destroy' do
    it 'should call logout_keeping_session!' do
      controller.should_receive(:logout_keeping_session!).once
      get :destroy
    end

    it 'should redirect to the root' do
      get :destroy
      response.should redirect_to('/')
    end
  end
end
