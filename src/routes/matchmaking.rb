require "sinatra/base"
require "json"
require "securerandom"
require_relative "../utils/helpers"
require_relative "../utils/config"

class MatchmakingRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/fortnite/api/matchmaking/session/findPlayer/*" do
    status 200
    ""
  end

  get "/fortnite/api/game/v2/matchmakingservice/ticket/player/:accountId" do
    bucket_id = params[:bucketId] || "0:EU:default:default"
    response.set_cookie("currentbuildUniqueId", value: bucket_id, http_only: false)
    status 200
    { serviceUrl: "ws://127.0.0.1", ticketType: "mms-player", payload: "69=", signature: "420=" }.to_json
  end

  get "/fortnite/api/game/v2/matchmaking/account/:accountId/session/:sessionId" do
    status 200
    { accountId: params[:accountId], sessionId: params[:sessionId], key: SecureRandom.hex(16).upcase }.to_json
  end

  get "/fortnite/api/matchmaking/session/:session_id" do
    bucket_id  = request.cookies["currentbuildUniqueId"] || "0:EU:Playlist_DefaultSolo:0"
    parts      = bucket_id.split(":")
    region     = parts[1] || "EU"
    playlist   = parts[2] || "Playlist_DefaultSolo"
    build_id   = parts[0] || "0"

    status 200
    {
      id:               params[:session_id],
      ownerId:          SecureRandom.hex(16).upcase,
      ownerName:        "[DS]fortnite-live",
      serverName:       "[DS]fortnite-live",
      serverAddress:    $game_ip,
      serverPort:       $game_port,
      maxPublicPlayers: 220,
      openPublicPlayers:175,
      maxPrivatePlayers:0,
      openPrivatePlayers:0,
      attributes: {
        REGION_s:             region,
        GAMEMODE_s:           "FORTATHENA",
        ALLOWBROADCASTING_b:  true,
        SUBREGION_s:          "GB",
        DCID_s:               "FORTNITE-LIVE",
        tenant_s:             "Fortnite",
        MATCHMAKINGPOOL_s:    "Any",
        STORMSHIELDDEFENSETYPE_i: 0,
        HOTFIXVERSION_i:      0,
        PLAYLISTNAME_s:       playlist,
        SESSIONKEY_s:         SecureRandom.hex(16).upcase,
        TENANT_s:             "Fortnite",
        BEACONPORT_i:         15009
      },
      publicPlayers:  [],
      privatePlayers: [],
      totalPlayers:   45,
      allowJoinInProgress: false,
      shouldAdvertise: false,
      isDedicated: false,
      usesStats: false,
      allowInvites: false,
      usesPresence: false,
      allowJoinViaPresence: true,
      allowJoinViaPresenceFriendsOnly: false,
      buildUniqueId: build_id,
      lastUpdated: Time.now.utc.iso8601(3),
      started: false
    }.to_json
  end

  post "/fortnite/api/matchmaking/session/*/join" do
    status 204
    ""
  end

  post "/fortnite/api/matchmaking/session/matchMakingRequest" do
    status 200
    [].to_json
  end
end
