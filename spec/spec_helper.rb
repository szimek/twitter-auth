begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

class TwitterUser < ActiveRecord::Base
  def self.table_name; 'twitter_auth_users' end
  include TwitterAuth::User
end

class User < ActiveRecord::Base
  belongs_to :twitter_user, :foreign_key => 'twitter_id'
end

require 'remarkable_rails'
require File.dirname(__FILE__) + '/fixtures/factories'
require File.dirname(__FILE__) + '/fixtures/fakeweb'
require File.dirname(__FILE__) + '/fixtures/twitter'

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

load(File.dirname(__FILE__) + '/schema.rb')

def define_basic_user_class!
  TwitterUser.send :include, TwitterAuth::User::Auth::HTTPBasic
end

def define_oauth_user_class!
  TwitterUser.send :include, TwitterAuth::User::Auth::Oauth
end

def stub_oauth!
  TwitterAuth.stub!(:config).and_return({
    'strategy' => 'oauth',
    'oauth_consumer_key' => 'testkey',
    'oauth_consumer_secret' => 'testsecret'
  })
  define_oauth_user_class!
end

def stub_basic!
  TwitterAuth.stub!(:config).and_return({
    'strategy' => 'basic',
    'encryption_key' => 'secretcode'
  })
  define_basic_user_class!
end

define_oauth_user_class!
