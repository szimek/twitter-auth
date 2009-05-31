class TwitterUser < ActiveRecord::Base
  include TwitterAuth::User
  include TwitterAuth.oauth? ? TwitterAuth::User::Auth::Oauth : TwitterAuth::User::Auth::HTTPBasic
end
