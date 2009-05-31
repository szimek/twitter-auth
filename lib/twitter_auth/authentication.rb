module TwitterAuth
  # These methods borrow HEAVILY from Rick Olsen's
  # Restful Authentication. All cleverness props
  # go to him, not me.
  module Authentication
    def self.included(base)
      base.send :helper_method, :current_user, :logged_in?, :authorized?
      base.send :hide_action, :current_user, :logged_in?
    end

    def current_user
      @current_user ||= (user_from_session || user_from_cookie)
    end

    def logged_in?
      !!current_user
    end
    
    protected

    def authentication_failed(message, destination='/')
      flash[:error] = message
      redirect_to destination
    end

    def authentication_succeeded(message = 'You have logged in successfully.', destination = '/')
      after_authentication_succeeded
      flash[:notice] = message
      redirect_to destination
    end

    def after_authentication_succeeded
    end

    def user_from_session
      if session[:user_id]
        ::User.find_by_id(session[:user_id])
      end
    end

    def user_from_cookie
      if token = cookies[:remember_token]
        if twitter_user = TwitterUser.from_remember_token(token)
          twitter_user.user
        end
      end
    end

    def current_user=(new_user)
      session[:user_id] = new_user.id
      @current_user = new_user
    end

    def authorized?
      !!current_user
    end

    def login_required
      authorized? || access_denied
    end

    def access_denied
      store_location
      redirect_to twitter_login_path
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end

    def logout_keeping_session!
      session[:user_id] = nil
      @current_user = nil
      cookies.delete(:remember_token)
    end
  end
end
