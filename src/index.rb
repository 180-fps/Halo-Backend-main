require "dotenv/load"
require "sinatra/base"
require "json"

require_relative "utils/helpers"
require_relative "utils/config"

require_relative "routes/auth"
require_relative "routes/account"
require_relative "routes/cloudstorage"
require_relative "routes/contentpages"
require_relative "routes/datarouter"
require_relative "routes/lightswitch"
require_relative "routes/storefront"
require_relative "routes/friends"
require_relative "routes/privacy"
require_relative "routes/mcp"
require_relative "routes/version"
require_relative "routes/matchmaking"
require_relative "routes/party"
require_relative "routes/discovery"
require_relative "routes/tournaments"
require_relative "routes/stats"
require_relative "routes/vivox"
require_relative "routes/misc"
require_relative "utils/errors"

require_relative "xmpp/server"
require_relative "xmpp/matchmaker_ws"

PORT = (ENV["PORT"] || 3551).to_i

class App < Sinatra::Base
  use PartyRoutes
  use DiscoveryRoutes
  use PrivacyRoutes
  use AuthRoutes
  use AccountRoutes
  use CloudStorageRoutes
  use ContentPagesRoutes
  use DataRouterRoutes
  use LightswitchRoutes
  use StorefrontRoutes
  use FriendsRoutes
  use McpRoutes
  use VersionRoutes
  use MatchmakingRoutes
  use TournamentRoutes
  use StatsRoutes
  use VivoxRoutes
  use MiscRoutes

  configure do
    set :show_exceptions, false
    set :raise_errors,    false
  end

  Errors.register(self)
end

Faye::WebSocket.load_adapter("puma")

require "rack/handler/puma"

builder = Rack::Builder.new do
  map "/" do
    run App
  end
  map "/ws/xmpp" do
    run XmppWsApp
  end
  map "/ws/matchmaker" do
    run MatchmakerWsApp
  end
end

Rack::Handler::Puma.run(builder, Port: PORT, Host: "0.0.0.0") do |server|
  puts "Server started on port #{PORT}"
end
