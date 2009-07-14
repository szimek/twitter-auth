class TwitterAuth::SessionsController < ApplicationController
  unloadable

  skip_before_filter :login_required

  def new
    if TwitterAuth.oauth?
      # TODO raise timeout exception if twitter is not responding
      @request_token = TwitterAuth.consumer.get_request_token
      session[:request_token] = @request_token.token
      session[:request_token_secret] = @request_token.secret

      url = @request_token.authorize_url
      url << "&oauth_callback=#{CGI.escape(TwitterAuth.oauth_callback)}" if TwitterAuth.oauth_callback?
      redirect_to url
    else
      # we don't have to do anything, it's just a simple form for HTTP basic!
    end
  end

  def create
    logout_keeping_session!
    if user = TwitterUser.authenticate(params[:login], params[:password])
      self.current_user = user.user
      authentication_succeeded and return
    else
      authentication_failed('Unable to verify your credentials through Twitter. Please try again.', '/login') and return
    end
  end

  def oauth_callback
    unless session[:request_token] && session[:request_token_secret]
      authentication_failed('No authentication information was found in the session. Please try again.') and return
    end

    unless params[:oauth_token].blank? || session[:request_token] ==  params[:oauth_token]
      authentication_failed('Authentication information does not match session information. Please try again.') and return
    end

    @request_token = OAuth::RequestToken.new(TwitterAuth.consumer, session[:request_token], session[:request_token_secret])

    @access_token = @request_token.get_access_token

    # The request token has been invalidated
    # so we nullify it in the session.
    session[:request_token] = nil
    session[:request_token_secret] = nil

    @twitter_user = TwitterUser.identify_or_create_from_access_token(@access_token)

    if @user = current_user
      if twitter_account = @twitter_user.user
        merge_account(twitter_account) if @user.id != twitter_account.id
      else
        @user.update_attributes(:twitter_id => @twitter_user.id)
      end
    else
      sign_in
    end

    # TODO leave it in User or move it to TwitterUser?
    # cookies[:remember_token] = @user.twitter_user.remember_me

    authentication_succeeded
  rescue Net::HTTPServerException, Net::HTTPFatalError, TwitterAuth::Dispatcher::Error => e
    case e.message
      when '401 "Unauthorized"'
        authentication_failed('This authentication request is no longer valid. Please try again.') and return
      else
        authentication_failed('There was a problem trying to authenticate you. Please try again.') and return
    end
  end

  def destroy
    logout_keeping_session!
    redirect_to '/'
  end

  protected
  def merge_account(account)
    User.transaction do
      before_merging_accounts(@user, account) if respond_to?(:before_merging_account)
      account.destroy
      @user.update_attributes(:twitter_id => @twitter_user.id)
    end
  end

  def sign_in
    @user = ::User.find_or_create_by_twitter_id(@twitter_user.id)
    session[:user_id] = @user.id
  end
end
