module TwitterAuth
  module Dispatcher    
    class Oauth < Grackle::Client
      include TwitterAuth::Dispatcher::Shared
      
      def initialize(user)
        raise TwitterAuth::Error, 'Dispatcher must be initialized with a User.' unless user.is_a?(TwitterAuth::OauthUser)

        super(:ssl => true,
              :auth => {
                :type => :oauth,
                :consumer_key => TwitterAuth.consumer.key,
                :consumer_secret => TwitterAuth.consumer.secret,
                :token => user.access_token,
                :token_secret => user.access_secret
              })
      end
    end    
  end
end
