require "sinatra/base"
require "json"

$display_name ||= "Reverse"

class AccountRoutes < Sinatra::Base
  post "/fortnite/api/game/v2/tryPlayOnPlatform/account/:accountId" do
    content_type "text/plain"
    status 200
    "true"
  end

  get "/account/api/public/account" do
    content_type :json
    status 200
    ids = params[:accountId]
    ids = [ids] if ids.is_a?(String)
    ids = [] unless ids.is_a?(Array)
    ids.map do |id|
      id = id.split("@")[0] if id.include?("@")
      { id: id, displayName: id, externalAuths: {} }
    end.to_json
  end

  get "/account/api/public/account/:accountId" do
    content_type :json
    status 200
    account_id = params[:accountId]
    $display_name = account_id.include?("@") ? account_id.split("@")[0] : account_id
    {
      id: account_id,
      displayName: $display_name,
      name: $display_name,
      email: "#{$display_name}@reverse.com",
      failedLoginAttempts: 0,
      lastLogin: Time.now.utc.iso8601(3),
      numberOfDisplayNameChanges: 0,
      ageGroup: "UNKNOWN",
      headless: false,
      country: "US",
      lastName: "Server",
      preferredLanguage: "en",
      canUpdateDisplayName: false,
      tfaEnabled: false,
      emailVerified: true,
      minorVerified: false,
      minorExpected: false,
      minorStatus: "NOT_MINOR",
      cabinedMode: false,
      hasHashedEmail: false
    }.to_json
  end

  get "/account/api/public/account/:accountId/externalAuths" do
    content_type :json
    status 200
    [].to_json
  end

  get "/epic/id/v2/sdk/accounts" do
    content_type :json
    status 200
    [{
      accountId: $display_name,
      displayName: $display_name,
      preferredLanguage: "en",
      cabinedMode: false,
      empty: false
    }].to_json
  end

  get "/fortnite/api/game/v2/enabled_features" do
    content_type :json
    status 200
    [].to_json
  end

  get "/content-controls/:accountId" do
    content_type :json
    status 200
    [].to_json
  end

  post "/api/v1/user/setting" do
    content_type :json
    status 200
    [].to_json
  end

  get "/socialban/api/public/v1/:accountId" do
    content_type :json
    status 200
    { bans: [], warnings: [] }.to_json
  end

  get "/presence/api/v1/_/:accountId/settings/subscriptions" do
    content_type :json
    status 200
    [].to_json
  end
end
