require 'factory_girl'

Factory.define(:user) do |u|
end

Factory.define(:twitter_oauth_user, :class => TwitterUser) do |u|
  u.id { TwitterUser.count + 1 }
  u.login 'twitterman'
  u.access_token 'fakeaccesstoken'
  u.access_secret 'fakeaccesstokensecret'
  
  u.name 'Twitter Man'
  u.description 'Saving the world for all Twitter kind.'

  u.association :user
end

Factory.define(:twitter_basic_user, :class => TwitterUser) do |u|
  u.id { TwitterUser.count + 1 }
  u.login 'twitterman'
  u.password 'test'

  u.name 'Twitter Man'
  u.description 'Saving the world for all Twitter kind.'

  u.association :user
end
