require "sinatra/base"
require "json"

FRIENDS_FILE  = File.join(__dir__, "../responses/friendslist.json")
FRIENDS2_FILE = File.join(__dir__, "../responses/friendslist2.json")

def load_friends_data
  f  = File.exist?(FRIENDS_FILE)  ? JSON.parse(File.read(FRIENDS_FILE))  : []
  f2 = File.exist?(FRIENDS2_FILE) ? JSON.parse(File.read(FRIENDS2_FILE)) : { "friends" => [], "incoming" => [], "outgoing" => [], "blocklist" => [], "settings" => { "acceptInvites" => "public" } }
  [f, f2]
end

def save_friends_data(f, f2)
  File.write(FRIENDS_FILE,  JSON.generate(f))
  File.write(FRIENDS2_FILE, JSON.generate(f2))
rescue; end

def xmpp_send_friend_event(to_id, payload)
  return unless defined?($xmpp_clients) && $xmpp_clients
  target = $xmpp_clients.find { |c| c[:account_id] == to_id }
  return unless target
  target[:ws].send(
    "<message from='xmpp-admin@prod.ol.epicgames.com' to='#{target[:jid]}' xmlns='jabber:client'>" \
    "<body>#{payload.to_json}</body></message>"
  ) rescue nil
end

class FriendsRoutes < Sinatra::Base
  before { content_type :json }

  get "/friends/api/v1/*/settings" do
    status 200
    {}.to_json
  end

  get "/friends/api/v1/*/blocklist" do
    status 200
    [].to_json
  end

  get "/friends/api/public/list/fortnite/*/recentPlayers" do
    status 200
    [].to_json
  end

  get "/friends/api/public/friends/:accountId" do
    status 200
    f, _ = load_friends_data
    response = []
    f.each do |entry|
      response << { "accountId" => entry["accountId"], "status" => entry["status"] || "ACCEPTED",
                    "direction" => entry["direction"] || "OUTBOUND", "created" => entry["created"], "favorite" => false }
    end
    response.to_json
  end

  post "/friends/api/*/friends*/:receiverId" do
    f, f2 = load_friends_data
    sender_id   = $display_name
    receiver_id = params[:receiverId]
    now = Time.now.utc.iso8601(3)

    outgoing = f2["outgoing"] ||= []
    incoming = f2["incoming"] ||= []
    accepted = f2["friends"]  ||= []

    if incoming.any? { |i| i["accountId"] == receiver_id }
      incoming.reject! { |i| i["accountId"] == receiver_id }
      accepted << { "accountId" => receiver_id, "groups" => [], "mutual" => 0, "alias" => "", "note" => "", "favorite" => false, "created" => now }
      f << { "accountId" => receiver_id, "status" => "ACCEPTED", "direction" => "OUTBOUND", "created" => now, "favorite" => false }
      xmpp_send_friend_event(sender_id, { "payload" => { "accountId" => receiver_id, "status" => "ACCEPTED", "direction" => "OUTBOUND", "created" => now, "favorite" => false }, "type" => "com.epicgames.friends.core.apiobjects.Friend", "timestamp" => now })
      xmpp_send_friend_event(receiver_id, { "payload" => { "accountId" => sender_id, "status" => "ACCEPTED", "direction" => "OUTBOUND", "created" => now, "favorite" => false }, "type" => "com.epicgames.friends.core.apiobjects.Friend", "timestamp" => now })
    elsif !outgoing.any? { |o| o["accountId"] == receiver_id }
      outgoing << { "accountId" => receiver_id, "favorite" => false }
      f << { "accountId" => receiver_id, "status" => "PENDING", "direction" => "OUTBOUND", "created" => now, "favorite" => false }
      xmpp_send_friend_event(sender_id, { "payload" => { "accountId" => receiver_id, "status" => "PENDING", "direction" => "OUTBOUND", "created" => now, "favorite" => false }, "type" => "com.epicgames.friends.core.apiobjects.Friend", "timestamp" => now })
      xmpp_send_friend_event(receiver_id, { "payload" => { "accountId" => sender_id, "status" => "PENDING", "direction" => "INBOUND", "created" => now, "favorite" => false }, "type" => "com.epicgames.friends.core.apiobjects.Friend", "timestamp" => now })
    end

    save_friends_data(f, f2)
    status 204
    ""
  end

  delete "/friends/api/*/friends*/:receiverId" do
    f, f2 = load_friends_data
    rid   = params[:receiverId]
    now   = Time.now.utc.iso8601(3)
    f.reject! { |e| e["accountId"] == rid }
    %w[friends incoming outgoing blocked].each { |k| f2[k]&.reject! { |e| e["accountId"] == rid } }
    save_friends_data(f, f2)
    xmpp_send_friend_event($display_name, { "payload" => { "accountId" => rid, "reason" => "DELETED" }, "type" => "com.epicgames.friends.core.apiobjects.FriendRemoval", "timestamp" => now })
    xmpp_send_friend_event(rid, { "payload" => { "accountId" => $display_name, "reason" => "DELETED" }, "type" => "com.epicgames.friends.core.apiobjects.FriendRemoval", "timestamp" => now })
    status 204
    ""
  end

  post "/friends/api/*/blocklist*/:receiverId" do
    f, f2 = load_friends_data
    rid = params[:receiverId]
    f.reject! { |e| e["accountId"] == rid }
    %w[friends incoming outgoing].each { |k| f2[k]&.reject! { |e| e["accountId"] == rid } }
    f2["blocklist"] ||= []
    f2["blocklist"] << { "accountId" => rid } unless f2["blocklist"].any? { |b| b["accountId"] == rid }
    save_friends_data(f, f2)
    status 204
    ""
  end

  delete "/friends/api/*/blocklist*/:receiverId" do
    _, f2 = load_friends_data
    f2["blocklist"]&.reject! { |b| b["accountId"] == params[:receiverId] }
    f, _ = load_friends_data
    save_friends_data(f, f2)
    status 204
    ""
  end

  get "/friends/api/v1/:accountId/summary" do
    status 200
    _, f2 = load_friends_data
    f2.to_json
  end

  get "/friends/api/public/blocklist/*" do
    status 200
    _, f2 = load_friends_data
    { "blockedUsers" => (f2["blocklist"] || []).map { |b| b["accountId"] } }.to_json
  end

  put "/friends/api/v1/*/friends/:friendId/alias" do
    _, f2 = load_friends_data
    alias_val = request.body.read.to_s.strip
    idx = f2["friends"]&.find_index { |fr| fr["accountId"] == params[:friendId] }
    if idx
      f2["friends"][idx]["alias"] = alias_val
      f, _ = load_friends_data
      save_friends_data(f, f2)
    end
    status 204
    ""
  end

  delete "/friends/api/v1/*/friends/:friendId/alias" do
    _, f2 = load_friends_data
    idx = f2["friends"]&.find_index { |fr| fr["accountId"] == params[:friendId] }
    if idx
      f2["friends"][idx]["alias"] = ""
      f, _ = load_friends_data
      save_friends_data(f, f2)
    end
    status 204
    ""
  end
end
