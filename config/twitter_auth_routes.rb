ActionController::Routing::Routes.draw do |map|
  map.resource :session, :path_prefix => '/twitter', :name_prefix => 'twitter_', :controller => 'twitter_auth/sessions', :only => [:new, :create, :destroy]  
  map.twitter_login '/twitter/login', :controller => 'twitter_auth/sessions', :action => 'new'
  map.twitter_logout '/twitter/logout', :controller => 'twitter_auth/sessions', :action => 'destroy'
  map.twitter_oauth_callback '/twitter/oauth_callback', :controller => 'twitter_auth/sessions', :action => 'oauth_callback'
end
