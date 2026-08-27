require "sinatra/base"
require "json"
require "securerandom"

$parties      = {}
$member_party = {}

def make_party_id
  SecureRandom.hex(16).upcase
end

def build_party(party_id, captain_id, config, join_info)
  now = Time.now.utc.iso8601(3)
  member = build_member(captain_id, join_info, "CAPTAIN")
  {
    "id"           => party_id,
    "created_at"   => now,
    "updated_at"   => now,
    "config"       => config || { "type" => "DEFAULT", "joinability" => "OPEN", "discoverability" => "ALL" },
    "members"      => [member],
    "meta"         => {},
    "invites"      => [],
    "revision"     => 0,
    "intentions"   => []
  }
end

def build_member(account_id, join_info, role = "MEMBER")
  now = Time.now.utc.iso8601(3)
  {
    "account_id"        => account_id,
    "meta"              => join_info&.dig("meta") || {},
    "connections"       => [join_info&.dig("connection") || {}],
    "role"              => role,
    "revision"          => 0,
    "joined_at"         => now,
    "updated_at"        => now
  }
end

def user_party_info(account_id)
  party_id = $member_party[account_id]
  party    = party_id ? $parties[party_id] : nil
  {
    "current"  => party ? [party] : [],
    "invites"  => [],
    "pending"  => [],
    "pings"    => []
  }
end

class PartyRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/party/api/v1/Fortnite/user/:accountId" do
    status 200
    user_party_info(params[:accountId]).to_json
  end

  post "/party/api/v1/Fortnite/parties" do
    body_data = JSON.parse(request.body.read) rescue {}
    raw_id    = body_data.dig("join_info", "connection", "id") || ""
    account_id = raw_id.split("@prod")[0]

    return status(400) && { error: "Missing join_info" }.to_json if account_id.empty?

    if (old_pid = $member_party[account_id])
      party = $parties[old_pid]
      if party
        party["members"].reject! { |m| m["account_id"] == account_id }
        $parties.delete(old_pid) if party["members"].empty?
      end
    end

    party_id = make_party_id
    party = build_party(party_id, account_id, body_data["config"], body_data["join_info"])
    $parties[party_id]       = party
    $member_party[account_id] = party_id

    status 200
    party.to_json
  end

  get "/party/api/v1/Fortnite/parties/:partyId" do
    party = $parties[params[:partyId]]
    if party
      status 200
      party.to_json
    else
      status 404
      { errorCode: "errors.com.epicgames.social.party.party_not_found", errorMessage: "Party not found" }.to_json
    end
  end

  patch "/party/api/v1/Fortnite/parties/:partyId" do
    party = $parties[params[:partyId]]
    return status(404) && {}.to_json unless party
    body_data = JSON.parse(request.body.read) rescue {}
    party["meta"].merge!(body_data["meta"] || {})
    party["config"].merge!(body_data["config"] || {})
    party["updated_at"] = Time.now.utc.iso8601(3)
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/join" do
    party = $parties[params[:partyId]]
    return status(404) && {}.to_json unless party
    body_data  = JSON.parse(request.body.read) rescue {}
    account_id = params[:accountId]

    $member_party[account_id] = params[:partyId]
    party["members"] << build_member(account_id, body_data, "MEMBER")
    party["updated_at"] = Time.now.utc.iso8601(3)
    status 204
    ""
  end

  delete "/party/api/v1/Fortnite/parties/:partyId/members/:accountId" do
    party = $parties[params[:partyId]]
    if party
      party["members"].reject! { |m| m["account_id"] == params[:accountId] }
      $parties.delete(params[:partyId]) if party["members"].empty?
    end
    $member_party.delete(params[:accountId])
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/leave" do
    party = $parties[params[:partyId]]
    if party
      party["members"].reject! { |m| m["account_id"] == params[:accountId] }
      $parties.delete(params[:partyId]) if party["members"].empty?
    end
    $member_party.delete(params[:accountId])
    status 204
    ""
  end

  patch "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/meta" do
    party = $parties[params[:partyId]]
    return status(204) && "" unless party
    body_data = JSON.parse(request.body.read) rescue {}
    member = party["members"].find { |m| m["account_id"] == params[:accountId] }
    if member
      member["meta"].merge!(body_data["update"] || {})
      (body_data["delete"] || []).each { |k| member["meta"].delete(k) }
      member["updated_at"] = Time.now.utc.iso8601(3)
    end
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/update" do
    party = $parties[params[:partyId]]
    return status(204) && "" unless party
    body_data = JSON.parse(request.body.read) rescue {}
    member = party["members"].find { |m| m["account_id"] == params[:accountId] }
    if member
      member["meta"].merge!(body_data["update"] || body_data || {})
      member["updated_at"] = Time.now.utc.iso8601(3)
    end
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/promote" do
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/kick" do
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/invites" do
    status 200
    { status: "sent" }.to_json
  end

  delete "/party/api/v1/Fortnite/parties/:partyId/invites/:accountId" do
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/parties/:partyId/intentions*" do
    status 204
    ""
  end

  delete "/party/api/v1/Fortnite/parties/:partyId/intentions*" do
    status 204
    ""
  end

  post "/party/api/v1/Fortnite/user/:accountId/pings/:pingerId" do
    status 204
    ""
  end

  delete "/party/api/v1/Fortnite/user/:accountId/pings/:pingerId" do
    status 204
    ""
  end

  get "/party/api/v1/Fortnite/parties/:partyId/members/:accountId/context" do
    status 200
    {}.to_json
  end

  get "/party/api/v1/Fortnite/user/:accountId/pings" do
    status 200
    [].to_json
  end
end
