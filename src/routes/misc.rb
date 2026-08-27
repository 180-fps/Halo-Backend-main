require "sinatra/base"
require "json"
require "time"
require_relative "../utils/helpers"
require_relative "../utils/config"

SDK_V1        = JSON.parse(File.read(File.join(__dir__, "../responses/sdkv1.json")))
EPIC_SETTINGS = JSON.parse(File.read(File.join(__dir__, "../responses/epic-settings.json")))

NAMED_LOCATIONS_CH2 = [
  "Athena_POI_01","Athena_POI_02","Athena_POI_03","Athena_POI_04","Athena_POI_05",
  "Athena_POI_06","Athena_POI_07","Athena_POI_08","Athena_POI_09","Athena_POI_10",
  "Athena_POI_11","Athena_POI_12","Athena_POI_13","Athena_POI_14","Athena_POI_15",
  "Athena_POI_16","Athena_POI_17","Athena_POI_18","Athena_POI_19","Athena_POI_20"
].freeze

class MiscRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/waitingroom/api/waitingroom" do
    status 204
    ""
  end

  get "/eulatracking/api/shared/agreements/fn*" do
    status 200
    {}.to_json
  end

  post "/fortnite/api/game/v2/grant_access/*" do
    status 204
    ""
  end

  get "/fortnite/api/statsv2/account/:accountId" do
    status 200
    { startTime: 0, endTime: 0, stats: {}, accountId: params[:accountId] }.to_json
  end

  get "/statsproxy/api/statsv2/account/:accountId" do
    status 200
    { startTime: 0, endTime: 0, stats: {}, accountId: params[:accountId] }.to_json
  end

  get "/fortnite/api/stats/accountId/:accountId/bulk/window/alltime" do
    status 200
    { startTime: 0, endTime: 0, stats: {}, accountId: params[:accountId] }.to_json
  end

  post "/fortnite/api/statsv2/query" do
    status 200
    [].to_json
  end

  post "/statsproxy/api/statsv2/query" do
    status 200
    [].to_json
  end

  post "/fortnite/api/feedback/*" do
    status 204
    ""
  end

  post "/fortnite/api/game/v2/events/v2/setSubgroup/*" do
    status 204
    ""
  end

  get "/fortnite/api/receipts/v1/account/*/receipts" do
    status 200
    [].to_json
  end

  get "/fortnite/api/game/v2/br-inventory/account/*" do
    status 200
    { stash: { globalcash: 5000 } }.to_json
  end

  get "/presence/api/v1/_/*/last-online" do
    status 200
    {}.to_json
  end

  get "/account/api/epicdomains/ssodomains" do
    status 200
    ["unrealengine.com", "unrealtournament.com", "fortnite.com", "epicgames.com"].to_json
  end

  get "/sdk/v1/*" do
    status 200
    SDK_V1.to_json
  end

  get "/v1/epic-settings/public/users/*/values" do
    status 200
    EPIC_SETTINGS.to_json
  end

  post "/v1/epic-settings/public/users/*/values" do
    status 200
    EPIC_SETTINGS.to_json
  end

  put "/v1/epic-settings/public/users/*/values" do
    status 200
    EPIC_SETTINGS.to_json
  end

  get "/region" do
    status 200
    { continent: { code: "NA" }, country: { iso_code: "US" } }.to_json
  end

  post "/fortnite/api/game/v2/chat/*/*/*/pc" do
    status 200
    { "GlobalChatRooms" => [{ "roomName" => "global" }] }.to_json
  end

  post "/fortnite/api/game/v2/chat/*/recommendGeneralChatRooms/pc" do
    status 200
    {}.to_json
  end

  get "/fortnite/api/game/v2/twitch/*" do
    status 200
    ""
  end

  get "/fortnite/api/game/v2/enabled_features" do
    status 200
    [].to_json
  end

  post "/api/v1/user/setting" do
    status 200
    [].to_json
  end

  get "/fortnite/api/game/v2/homebase/allowed-name-chars" do
    status 200
    {
      ranges: [48,57,65,90,97,122,192,255,260,265,280,281,286,287,304,305,321,324,346,347,350,351,377,380,1024,1279,1536,1791,4352,4607,11904,12031,12288,12351,12352,12543,12592,12687,12800,13055,13056,13311,13312,19903,19968,40959,43360,43391,44032,55215,55216,55295,63744,64255,65072,65103,65281,65470,131072,173791,194560,195103],
      singlePoints: [32,39,45,46,95,126],
      excludedPoints: [208,215,222,247]
    }.to_json
  end

  get "/presence/api/v1/_/:accountId/settings/subscriptions" do
    status 200
    [].to_json
  end

  get "/fortnite/api/game/v2/friendcodes/*/epic" do
    status 200
    [].to_json
  end

  get "/content-controls/*" do
    status 200
    [].to_json
  end

  get "/fortnite/api/game/v2/world/info" do
    status 200
    path = File.join(__dir__, "../responses/Campaign/worldstw.json")
    File.exist?(path) ? File.read(path) : {}.to_json
  end

  post "/fortnite/api/game/v2/creative/discovery/surface/*" do
    status 200
    { results: [], hasMore: false }.to_json
  end

  get "/launcher/api/public/distributionpoints/" do
    status 200
    { distributions: ["https://epicgames-download1.akamaized.net/", "https://download.epicgames.com/"] }.to_json
  end

  get "/launcher/api/public/assets/*" do
    status 200
    { appName: "FortniteContentBuilds", labelName: "ReverseServer", buildVersion: "++Fortnite+Release-17.50", expires: "9999-12-31T23:59:59.999Z", items: {} }.to_json
  end

  post "/fortnite/api/game/v2/named_locations/poi*" do
    status 200
    info = get_version_info(request.user_agent)
    build_named_locations(info[:season]).to_json
  end

  get "/fortnite/api/game/v2/named_locations*" do
    status 200
    info = get_version_info(request.user_agent)
    build_named_locations(info[:season]).to_json
  end

  post "/api/v1/fortnite-br/*/target" do
    status 200
    path = File.join(__dir__, "../responses/Athena/motd.json")
    File.exist?(path) ? File.read(path) : { contentItems: [] }.to_json
  end

  get "/fortnite/api/game/v2/events/tournamentandhistory/*" do
    status 200
    path = File.join(__dir__, "../responses/Athena/Tournament/tournamentandhistory.json")
    File.exist?(path) ? File.read(path) : {}.to_json
  end

  post "/datarouter/api/v1/public/data" do
    status 204
    ""
  end

  get "/socialban/api/public/v1/*" do
    status 200
    { bans: [], warnings: [] }.to_json
  end

  get "/fortnite/api/game/v2/leaderboards/cohort/:accountId" do
    status 200
    { accountId: params[:accountId], cohortAccounts: [params[:accountId]], expiresAt: "9999-12-31T00:00:00.000Z", playlist: params[:playlist] }.to_json
  end

  get "/account/api/epicdomains/ssodomains" do
    status 200
    ["unrealengine.com", "unrealtournament.com", "fortnite.com", "epicgames.com"].to_json
  end

  post "/account/api/oauth/exchange" do
    status 200
    {}.to_json
  end

  private

  def build_named_locations(season)
    season = season.to_i
    if season >= 14 && season <= 23
      {
        namedLocations: NAMED_LOCATIONS_CH2.map { |id| { id: id, discovered: true, type: "namedlocation" } },
        landmarks: build_landmarks(season)
      }
    else
      { namedLocations: [], landmarks: [] }
    end
  end

  def build_landmarks(season)
    count = case season
            when 14..16 then 40
            when 17..19 then 35
            when 20..23 then 30
            else 0
            end
    count.times.map { |i| { id: "Athena_Landmark_#{(i+1).to_s.rjust(3,'0')}", discovered: true, type: "landmark" } }
  end
end
