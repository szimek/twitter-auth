# Credits for the code below go to guys at Thoughtbot
# and their Clearance engine
class ActionController::Routing::RouteSet
  def load_routes_with_twitter_auth!
    lib_path = File.dirname(__FILE__)
    twitter_auth_routes = File.join(lib_path, *%w[.. .. .. config twitter_auth_routes.rb])
    unless configuration_files.include?(twitter_auth_routes)
      add_configuration_file(twitter_auth_routes)
    end
    load_routes_without_twitter_auth!
  end

  alias_method_chain :load_routes!, :twitter_auth
end
