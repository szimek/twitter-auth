module TwitterAuth
  module Dispatcher
    module Shared
      def method_missing(name, *args)
        begin
          super
        rescue Grackle::TwitterError => e
          if e.status == 401
            raise TwitterAuth::Dispatcher::Unauthorized, 'The credentials provided did not authorize the user.'
          else
            message = e.response_object.error
            raise TwitterAuth::Dispatcher::Error, message
          end
        end
      end
      
      def post!(status)
        self.statuses.update!(:status => status)
      end
    end
  end
end
