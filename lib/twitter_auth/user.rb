module TwitterAuth
  module User
    def self.included(model)
      model.send(:include, TwitterAttributes)
      model.send(:include, Validations)
      model.send(:include, RememberMe)
      model.send(:include, TwitterDispatcher)

      model.class_eval do
        has_one :user, :foreign_key => "twitter_id"
      end
    end

    module TwitterAttributes
      def self.included(user)
        user.extend ClassMethods
      end

      TWITTER_ATTRIBUTES = [
                            :name,
                            :location,
                            :description,
                            :profile_image_url,
                            :url,
                            :protected,
                            :profile_background_color,
                            :profile_sidebar_fill_color,
                            :profile_link_color,
                            :profile_sidebar_border_color,
                            :profile_text_color,
                            :profile_background_image_url,
                            :profile_background_tile,
                            :friends_count,
                            :statuses_count,
                            :followers_count,
                            :favourites_count,
                            :time_zone,
                            :utc_offset
                           ]

      def assign_twitter_attributes(hash)
        TWITTER_ATTRIBUTES.each do |att|
          send("#{att}=", hash[att.to_s]) if respond_to?("#{att}=")
        end
      end

      def update_twitter_attributes(hash)
        assign_twitter_attributes(hash)
        save
      end

      module ClassMethods
        def new_from_twitter_hash(hash)
          raise ArgumentError, 'Invalid hash: must include screen_name.' unless hash.key?('screen_name')
          raise ArgumentError, 'Invalid hash: must include id.' unless hash.key?('id')

          user = self.new
          user.id = hash['id'].to_s
          user.login = hash['screen_name']

          TWITTER_ATTRIBUTES.each do |att|
            user.send("#{att}=", hash[att.to_s]) if user.respond_to?("#{att}=")
          end

          user
        end
      end
    end

    module Validations
      def self.included(model)
        model.class_eval do
          validates_presence_of   :login
          validates_format_of     :login, :with => /\A[a-z0-9_]+\z/i
          validates_length_of     :login, :in => 1..15
          validates_uniqueness_of :login, :case_sensitive => false
          validates_uniqueness_of :remember_token, :allow_blank => true
        end
      end
    end

    module RememberMe
      def self.included(model)
        model.extend ClassMethods

        model.class_eval do
          attr_protected :remember_token, :remember_token_expires_at
        end
      end

      def remember_me
        return false unless respond_to?(:remember_token)

        self.remember_token = ActiveSupport::SecureRandom.hex(10)
        self.remember_token_expires_at = Time.now + TwitterAuth.remember_for.days

        save

        {:value => self.remember_token, :expires => self.remember_token_expires_at}
      end

      def forget_me
        self.remember_token = self.remember_token_expires_at = nil
        self.save
      end

      module ClassMethods
        def from_remember_token(token)
          first(:conditions => ["remember_token = ? AND remember_token_expires_at > ?", token, Time.now])
        end
      end
    end

    module TwitterDispatcher
      def twitter
        if TwitterAuth.oauth?
          TwitterAuth::Dispatcher::Oauth.new(self)
        else
          TwitterAuth::Dispatcher::Basic.new(self)
        end
      end
    end

    module Auth
      module HTTPBasic
        def self.included(base)
          base.extend ClassMethods

          base.class_eval do
            attr_protected :crypted_password, :salt
          end
        end

        module ClassMethods
          def verify_credentials(login, password)
            response = TwitterAuth.net.start { |http|
              request = Net::HTTP::Get.new('/account/verify_credentials.json')
              request.basic_auth login, password
              http.request(request)
            }

            if response.code == '200'
              JSON.parse(response.body)
            else
              false
            end
          end

          def authenticate(login, password)
            if twitter_hash = verify_credentials(login, password)
              user = identify_or_create_from_twitter_hash_and_password(twitter_hash, password)
              user
            else
              nil
            end
          end

          def identify_or_create_from_twitter_hash_and_password(twitter_hash, password)
            if user = TwitterUser.find_by_id(twitter_hash['id'].to_s)
              user.login = twitter_hash['screen_name']
              user.assign_twitter_attributes(twitter_hash)
              user.password = password
              user.save
              user
            else
              user = TwitterUser.new_from_twitter_hash(twitter_hash)
              user.password = password
              user.save
              user
            end
          end
        end

        def password=(new_password)
          encrypted = TwitterAuth::Cryptify.encrypt(new_password)
          self.crypted_password = encrypted[:encrypted_data]
          self.salt = encrypted[:salt]
        end

        def password
          TwitterAuth::Cryptify.decrypt(self.crypted_password, self.salt)
        end
      end

      module Oauth
        def self.included(base)
          base.extend ClassMethods
          base.extend TwitterAuth::Dispatcher::Shared

          base.class_eval do
            attr_protected :access_token, :access_secret
          end
        end

        module ClassMethods
          def identify_or_create_from_access_token(token, secret=nil)
            raise ArgumentError, 'Must authenticate with an OAuth::AccessToken or the string access token and secret.' unless (token && secret) || token.is_a?(OAuth::AccessToken)

            token = OAuth::AccessToken.new(TwitterAuth.consumer, token, secret) unless token.is_a?(OAuth::AccessToken)

            response = token.get(TwitterAuth.path_prefix + '/account/verify_credentials.json')
            user_info = handle_response(response)

            if user = TwitterUser.find_by_id(user_info['id'].to_s)
              user.id = user_info['id']
              user.login = user_info['screen_name']
              user.assign_twitter_attributes(user_info)
              user.access_token = token.token
              user.access_secret = token.secret
              user.save
              user
            else
              TwitterUser.create_from_twitter_hash_and_token(user_info, token)
            end
          end

          def create_from_twitter_hash_and_token(user_info, access_token)
            user = TwitterUser.new_from_twitter_hash(user_info)
            user.access_token = access_token.token
            user.access_secret = access_token.secret
            user.save
            user
          end
        end

        def token
          OAuth::AccessToken.new(TwitterAuth.consumer, access_token, access_secret)
        end
      end
    end
  end
end
