require "sinatra/base"
require "json"

DISCOVERY_DATA = JSON.parse(File.read(File.join(__dir__, "../responses/Athena/Discovery/discovery_frontend.json")))

class DiscoveryRoutes < Sinatra::Base
  post "*/api/v2/discovery/surface/*" do
    content_type :json
    status 200
    (DISCOVERY_DATA["v2"] || {}).to_json
  end

  post "*/discovery/surface/*" do
    content_type :json
    status 200
    (DISCOVERY_DATA["v1"] || {}).to_json
  end

  get "/fortnite/api/discovery/accessToken/:branch" do
    content_type :json
    status 200
    { branchName: params[:branch], appId: "Fortnite", token: "eg1~fortnite" }.to_json
  end

  post "/links/api/fn/mnemonic" do
    content_type :json
    status 200
    results = DISCOVERY_DATA.dig("v2", "Panels", 1, "Pages", 0, "results") || []
    results.map { |r| r["linkData"] }.to_json
  end

  get "/links/api/fn/mnemonic/:playlist/related" do
    content_type :json
    status 200
    results = DISCOVERY_DATA.dig("v2", "Panels", 1, "Pages", 0, "results") || []
    links = {}
    results.each do |r|
      ld = r["linkData"]
      links[params[:playlist]] = ld if ld && ld["mnemonic"] == params[:playlist]
    end
    { parentLinks: [], links: links }.to_json
  end

  get "/links/api/fn/mnemonic/*" do
    content_type :json
    status 200
    mnemonic = request.path.split("/").last
    results  = DISCOVERY_DATA.dig("v2", "Panels", 1, "Pages", 0, "results") || []
    found    = results.find { |r| r.dig("linkData", "mnemonic") == mnemonic }
    (found ? found["linkData"] : {}).to_json
  end

  post "/api/v1/links/lock-status/:accountId/check" do
    content_type :json
    status 200
    body_data = JSON.parse(request.body.read) rescue {}
    results = (body_data["linkCodes"] || []).map do |code|
      { playerId: params[:accountId], linkCode: code, lockStatus: "UNLOCKED", lockStatusReason: "NONE", isVisible: true }
    end
    { results: results, hasMore: false }.to_json
  end

  post "/api/v1/assets/Fortnite/*/*" do
    content_type :json
    status 200
    body_data = JSON.parse(request.body.read) rescue {}
    discovery_assets_path = File.join(__dir__, "../responses/Athena/Discovery/discovery_api_assets.json")
    if body_data["FortCreativeDiscoverySurface"] == 0 && File.exist?(discovery_assets_path)
      File.read(discovery_assets_path)
    else
      { "FortCreativeDiscoverySurface" => { "meta" => { "promotion" => body_data["FortCreativeDiscoverySurface"] || 0 }, "assets" => {} } }.to_json
    end
  end
end
