module TwitterAuth
  module Dispatcher
    class Basic < Grackle::Client
      include TwitterAuth::Dispatcher::Shared
      
      def initialize(user)
        raise TwitterAuth::Error, 'Dispatcher must be initialized with a User.' unless user.is_a?(TwitterAuth::BasicUser)

        super(:ssl => true,
              :auth => {
                :type => :basic,
                :username => user.login,
                :password => user.password
              })
      end
    end
  end
end
