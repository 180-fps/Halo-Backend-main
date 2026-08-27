require "sinatra/base"
require "json"
require "openssl"
require "base64"
require "securerandom"
require_relative "../utils/config"

VIVOX_ISSUER    = ($config["vivox"]["issuer"]    rescue "reverse") || "reverse"
VIVOX_SECRET    = ($config["vivox"]["secret_key"] rescue "change_me") || "change_me"
VIVOX_DOMAIN    = ($config["vivox"]["domain"]    rescue "mt1s.vivox.com") || "mt1s.vivox.com"
VIVOX_SERVER    = ($config["vivox"]["server"]    rescue "https://mt1s.vivox.com") || "https://mt1s.vivox.com"
VIVOX_ENABLED   = ($config["vivox"]["enabled"].to_s.downcase == "true") rescue false

def vivox_user_uri(account_id)
  "sip:.#{VIVOX_ISSUER}.#{account_id}.@#{VIVOX_DOMAIN}"
end

def vivox_channel_uri(channel_name)
  "sip:confctl-g-#{VIVOX_ISSUER}.#{channel_name}@#{VIVOX_DOMAIN}"
end

def vivox_sign_token(payload)
  header  = Base64.urlsafe_encode64('{"alg":"HS256","typ":"JWT"}', padding: false)
  body    = Base64.urlsafe_encode64(payload.to_json, padding: false)
  signing = "#{header}.#{body}"
  sig     = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("sha256", VIVOX_SECRET, signing), padding: false)
  "#{signing}.#{sig}"
end

def vivox_login_token(account_id)
  vivox_sign_token({
    "iss" => VIVOX_ISSUER,
    "exp" => (Time.now.to_i + 90),
    "vxa" => "login",
    "vxi" => SecureRandom.hex(8).to_i(16),
    "f"   => vivox_user_uri(account_id),
    "sub" => VIVOX_SERVER
  })
end

def vivox_join_token(account_id, channel_uri)
  vivox_sign_token({
    "iss" => VIVOX_ISSUER,
    "exp" => (Time.now.to_i + 90),
    "vxa" => "join",
    "vxi" => SecureRandom.hex(8).to_i(16),
    "f"   => vivox_user_uri(account_id),
    "t"   => channel_uri,
    "sub" => VIVOX_SERVER
  })
end

def vivox_join_muted_token(account_id, channel_uri)
  vivox_sign_token({
    "iss" => VIVOX_ISSUER,
    "exp" => (Time.now.to_i + 90),
    "vxa" => "join_muted",
    "vxi" => SecureRandom.hex(8).to_i(16),
    "f"   => vivox_user_uri(account_id),
    "t"   => channel_uri,
    "sub" => VIVOX_SERVER
  })
end

class VivoxRoutes < Sinatra::Base
  before { content_type :json }

  get "/vivox/api/v1/tokens" do
    return status(404) && {}.to_json unless VIVOX_ENABLED
    account_id  = $display_name
    action      = params[:action] || "login"
    channel_uri = params[:channel]
    target_uri  = params[:target]

    token = case action
    when "login"
      vivox_login_token(account_id)
    when "join"
      return status(400) && { error: "channel required" }.to_json unless channel_uri
      vivox_join_token(account_id, channel_uri)
    when "join_muted"
      return status(400) && { error: "channel required" }.to_json unless channel_uri
      vivox_join_muted_token(account_id, channel_uri)
    else
      return status(400) && { error: "unknown action" }.to_json
    end

    status 200
    { token: token }.to_json
  end

  get "/vivox/api/v1/tokens/bulk" do
    return status(404) && {}.to_json unless VIVOX_ENABLED
    account_id  = $display_name
    channel_uri = params[:channel]

    resp = {
      login_token: vivox_login_token(account_id),
      user_uri:    vivox_user_uri(account_id)
    }

    if channel_uri && !channel_uri.empty?
      resp[:join_token]   = vivox_join_token(account_id, channel_uri)
      resp[:channel_uri]  = channel_uri
    end

    status 200
    resp.to_json
  end

  get "/vivox/api/v1/channel/:channelName" do
    return status(404) && {}.to_json unless VIVOX_ENABLED
    status 200
    { channel_uri: vivox_channel_uri(params[:channelName]) }.to_json
  end
end
