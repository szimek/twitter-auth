module TwitterAuth
  module Extensions
    module ActiveRecord
      def self.included(model)
        model.extend ClassMethods
      end

      module ClassMethods
        def twitter_authenticated
          belongs_to :twitter_user, :foreign_key => 'twitter_id'
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, TwitterAuth::Extensions::ActiveRecord)
