require "sinatra/base"
require "json"

$display_name = "Reverse"

class AuthRoutes < Sinatra::Base
  post "/account/api/oauth/token" do
    content_type :json
    status 200

    body_params = request.body.read
    parsed = URI.decode_www_form(body_params).to_h rescue {}
    username = parsed["username"] || ""
    username = username.split("@")[0] unless username.empty?
    $display_name = username unless username.empty?

    {
      access_token: "eg1~fortnite",
      expires_in: 28800,
      expires_at: "9999-12-02T01:12:01.100Z",
      token_type: "bearer",
      refresh_token: "eg1~fortnite",
      refresh_expires: 86400,
      refresh_expires_at: "9999-12-02T01:12:01.100Z",
      account_id: $display_name,
      client_id: "fortnite",
      internal_client: true,
      client_service: "fortnite",
      displayName: $display_name,
      app: "fortnite",
      in_app_id: $display_name,
      device_id: "fortnite"
    }.to_json
  end

  get "/account/api/oauth/verify" do
    content_type :json
    status 200
    {
      token: "eg1~fortnite",
      session_id: "3c3662bcb661d6de679c636744c66b62",
      token_type: "bearer",
      client_id: "fortnite",
      internal_client: true,
      client_service: "fortnite",
      account_id: $display_name,
      expires_in: 28800,
      expires_at: "9999-12-02T01:12:01.100Z",
      auth_method: "exchange_code",
      display_name: $display_name,
      app: "fortnite",
      in_app_id: $display_name,
      device_id: "fortnite"
    }.to_json
  end

  post "/account/api/oauth/exchange" do
    content_type :json
    status 200
    {}.to_json
  end

  delete "/account/api/oauth/sessions/kill" do
    status 204
    ""
  end

  delete "/account/api/oauth/sessions/kill/:token" do
    status 204
    ""
  end

  post "/auth/v1/oauth/token" do
    content_type :json
    status 200
    {
      access_token: "eg1~fortnite",
      token_type: "bearer",
      expires_in: 28800,
      expires_at: "9999-12-31T23:59:59.999Z",
      nonce: "fortnite",
      features: ["AntiCheat", "CommerceService", "Connect", "ContentService", "Ecom", "EpicConnect", "Inventories", "LockerService", "MagpieService", "Matchmaking Service", "PCBService", "QuestService", "Stats"],
      deployment_id: "fortnite",
      organization_id: "fortnite",
      organization_user_id: "fortnite",
      product_id: "prod-fn",
      product_user_id: "fortnite",
      product_user_id_created: false,
      id_token: "fortnite",
      sandbox_id: "fn"
    }.to_json
  end

  post "/epic/oauth/v2/token" do
    content_type :json
    status 200
    {
      scope: "basic_profile friends_list openid presence",
      token_type: "bearer",
      access_token: "eg1~fortnite",
      expires_in: 28800,
      expires_at: "9999-12-31T23:59:59.999Z",
      refresh_token: "eg1~fortnite",
      refresh_expires_in: 86400,
      refresh_expires_at: "9999-12-31T23:59:59.999Z",
      account_id: $display_name,
      client_id: "fortnite",
      application_id: "fortnite",
      selected_account_id: $display_name,
      id_token: "eg1~fortnite"
    }.to_json
  end
end
