require "sinatra/base"
require "json"

PRIVACY_FILE = File.join(__dir__, "../responses/privacy.json")
privacy_data = JSON.parse(File.read(PRIVACY_FILE))

class PrivacyRoutes < Sinatra::Base
  get "/fortnite/api/game/v2/privacy/account/:accountId" do
    content_type :json
    status 200
    privacy_data = JSON.parse(File.read(PRIVACY_FILE))
    privacy_data["accountId"] = params[:accountId]
    privacy_data.to_json
  end

  post "/fortnite/api/game/v2/privacy/account/:accountId" do
    content_type :json
    status 200
    body_data = JSON.parse(request.body.read) rescue {}
    privacy_data = JSON.parse(File.read(PRIVACY_FILE))
    privacy_data["accountId"] = params[:accountId]
    privacy_data["optOutOfPublicLeaderboards"] = body_data["optOutOfPublicLeaderboards"] if body_data.key?("optOutOfPublicLeaderboards")
    File.write(PRIVACY_FILE, JSON.pretty_generate(privacy_data))
    privacy_data.to_json
  end
end
