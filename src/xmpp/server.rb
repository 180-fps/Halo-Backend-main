require "faye/websocket"
require "eventmachine"
require "json"
require "securerandom"
require "base64"
require_relative "../utils/helpers"

XMPP_HOST = "prod.ol.epicgames.com"
XMPP_ADMIN = "xmpp-admin@#{XMPP_HOST}"
FRIENDS_PATH = File.join(__dir__, "../responses/friendslist.json")

$xmpp_clients = []

def xmpp_make_id
  SecureRandom.uuid
end

def get_friend_ids(account_id)
  raw = JSON.parse(File.read(FRIENDS_PATH)) rescue []
  raw.map { |f| f["accountId"] }.compact.reject { |id| id == account_id }.to_set
rescue
  Set.new
end

def xmpp_safe_send(ws, data)
  ws.send(data) if ws.ready_state == Faye::WebSocket::OPEN
rescue; end

def build_presence_xml(from_jid, to_jid, away, status, offline)
  type = offline ? "unavailable" : "available"
  xml  = "<presence to='#{to_jid}' from='#{from_jid}' xmlns='jabber:client' type='#{type}'>"
  unless offline
    xml += "<show>away</show>" if away
    xml += "<status>#{status || "{}"}</status>"
  end
  xml + "</presence>"
end

def build_message_xml(from_jid, to_jid, id, body)
  id_attr = id && !id.empty? ? " id='#{id}'" : ""
  "<message from='#{from_jid}' to='#{to_jid}'#{id_attr} xmlns='jabber:client'><body>#{body}</body></message>"
end

def broadcast_presence(ws, status, away, offline)
  sender = $xmpp_clients.find { |c| c[:ws] == ws }
  return unless sender

  sender[:last_presence] = { away: away, status: status, offline: offline }
  friend_ids = get_friend_ids(sender[:account_id])

  $xmpp_clients.each do |client|
    next if client[:ws] == ws && !offline
    next unless client[:ws] == ws || friend_ids.include?(client[:account_id])
    xmpp_safe_send(client[:ws], build_presence_xml(sender[:jid], client[:jid], away, status, offline))
  end
end

def send_friends_presence_to(ws)
  receiver = $xmpp_clients.find { |c| c[:ws] == ws }
  return unless receiver
  friend_ids = get_friend_ids(receiver[:account_id])
  $xmpp_clients.each do |client|
    next if client[:ws] == ws
    next unless friend_ids.include?(client[:account_id])
    p = client[:last_presence]
    xmpp_safe_send(ws, build_presence_xml(client[:jid], receiver[:jid], p[:away], p[:status], p[:offline]))
  end
end

def remove_xmpp_client(ws)
  entry = $xmpp_clients.find { |c| c[:ws] == ws }
  return unless entry
  broadcast_presence(ws, entry.dig(:last_presence, :status), entry.dig(:last_presence, :away), true)
  $xmpp_clients.reject! { |c| c[:ws] == ws }
end

def broadcast_to_party(sender, msg_id, body)
  party_id = $member_party[sender[:account_id]] rescue nil
  party    = party_id ? $parties[party_id] : nil

  if party && party["members"]
    party["members"].each do |m|
      target = $xmpp_clients.find { |c| c[:account_id] == m["account_id"] }
      next unless target
      xmpp_safe_send(target[:ws], build_message_xml(sender[:jid], target[:jid], msg_id, body))
    end
  else
    xmpp_safe_send(sender[:ws], build_message_xml(sender[:jid], sender[:jid], msg_id, body))
  end
end

def find_client_by_jid(jid)
  $xmpp_clients.find { |c| c[:id] == jid || c[:jid] == jid }
end

def start_xmpp_server(port = 80)
  Thread.new do
    EM.run do
      EM.start_server("0.0.0.0", port, XmppTcpHandler)
      puts "XMPP listening on port #{port}"
    end
  end
end

class XmppWsApp
  def self.call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, ["xmpp"], ping: 30)
      session_id    = xmpp_make_id
      account_id    = ""
      jid           = ""
      bare_jid      = ""
      authenticated = false
      registered    = false

      ws.on :message do |event|
        raw = event.data.to_s.strip
        next if raw.empty?
        handle_xmpp_message(ws, raw, session_id,
          account_id, jid, bare_jid, authenticated, registered) do |updates|
          account_id    = updates[:account_id]    if updates[:account_id]
          jid           = updates[:jid]           if updates[:jid]
          bare_jid      = updates[:bare_jid]      if updates[:bare_jid]
          authenticated = updates[:authenticated] unless updates[:authenticated].nil?
          registered    = updates[:registered]    unless updates[:registered].nil?
        end
      end

      ws.on :close do
        remove_xmpp_client(ws)
      end

      ws.rack_response
    else
      [404, {}, ["Not a WebSocket"]]
    end
  end
end

def handle_xmpp_message(ws, raw, session_id, account_id, jid, bare_jid, authenticated, registered)
  root_name = raw.match(/<(\w[\w:]*)/)&.[](1)&.split(":")&.last || ""

  case root_name
  when "open"
    xmpp_safe_send(ws,
      "<open xmlns='urn:ietf:params:xml:ns:xmpp-framing' from='#{XMPP_HOST}' id='#{session_id}' version='1.0' xml:lang='en'/>")
    if authenticated
      xmpp_safe_send(ws,
        "<stream:features xmlns:stream='http://etherx.jabber.org/streams'>" \
        "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/>" \
        "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/></stream:features>")
    else
      xmpp_safe_send(ws,
        "<stream:features xmlns:stream='http://etherx.jabber.org/streams'>" \
        "<mechanisms xmlns='urn:ietf:params:xml:ns:xmpp-sasl'><mechanism>PLAIN</mechanism></mechanisms>" \
        "</stream:features>")
    end

  when "auth"
    content = raw.match(/<auth[^>]*>(.*?)<\/auth>/m)&.[](1).to_s.strip
    decoded = Base64.decode64(content) rescue ""
    parts   = decoded.split("\u0000")
    candidate = (parts[1] || parts[0]).to_s
    candidate = candidate.split("@")[0]

    if candidate.empty?
      ws.close; return
    end

    yield({ account_id: candidate, authenticated: true })
    xmpp_safe_send(ws, "<success xmlns='urn:ietf:params:xml:ns:xmpp-sasl'/>")

  when "iq"
    iq_id   = raw.match(/id=['"]([^'"]+)['"]/)&.[](1) || ""
    iq_type = raw.match(/type=['"]([^'"]+)['"]/)&.[](1) || "get"

    case iq_id
    when "_xmpp_bind1"
      resource = raw.match(/<resource>(.*?)<\/resource>/m)&.[](1) || ""
      new_jid  = "#{account_id}@#{XMPP_HOST}/#{resource}"
      new_bare = "#{account_id}@#{XMPP_HOST}"
      yield({ jid: new_jid, bare_jid: new_bare })

      xmpp_safe_send(ws,
        "<iq to='#{new_jid}' id='_xmpp_bind1' xmlns='jabber:client' type='result'>" \
        "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'><jid>#{new_jid}</jid></bind></iq>")

      unless registered
        $xmpp_clients << {
          ws: ws, account_id: account_id, jid: new_jid, id: new_bare,
          last_presence: { away: false, status: "{}", offline: false }
        }
        yield({ registered: true })
      end

    when "_xmpp_session1"
      xmpp_safe_send(ws,
        "<iq to='#{jid}' from='#{XMPP_HOST}' id='_xmpp_session1' xmlns='jabber:client' type='result'/>")
      send_friends_presence_to(ws)

    else
      if %w[get set].include?(iq_type)
        xmpp_safe_send(ws,
          "<iq to='#{jid.empty? ? account_id : jid}' from='#{XMPP_HOST}' id='#{iq_id}' xmlns='jabber:client' type='result'/>")
      end
    end

  when "message"
    body_match = raw.match(/<body>(.*?)<\/body>/m)
    return unless body_match

    body      = body_match[1]
    msg_to    = raw.match(/to=['"]([^'"]+)['"]/)&.[](1) || ""
    msg_id    = raw.match(/id=['"]([^'"]+)['"]/)&.[](1) || ""
    msg_type  = raw.match(/type=['"]([^'"]+)['"]/)&.[](1) || ""
    sender    = $xmpp_clients.find { |c| c[:ws] == ws }
    return unless sender

    if msg_type == "chat"
      target = find_client_by_jid(msg_to)
      return unless target
      xmpp_safe_send(target[:ws], build_message_xml(sender[:jid], target[:jid], msg_id, body))
      return
    end

    begin
      obj = JSON.parse(body)
      type_key = obj["type"].to_s.downcase
      case type_key
      when /invitation|invite/
        target = find_client_by_jid(msg_to)
        xmpp_safe_send(target[:ws], build_message_xml(sender[:jid], target[:jid], msg_id, body)) if target
      when /kicked|kick/
        target_id = obj["account_id"] || obj["kicked_member_id"]
        target = $xmpp_clients.find { |c| c[:account_id] == target_id }
        xmpp_safe_send(target[:ws], build_message_xml(XMPP_ADMIN, target[:jid], msg_id, body)) if target
      when /party/
        broadcast_to_party(sender, msg_id, body)
      else
        xmpp_safe_send(ws, build_message_xml(sender[:jid], sender[:jid], msg_id, body))
      end
    rescue
      xmpp_safe_send(ws, build_message_xml(sender[:jid], sender[:jid], msg_id, body))
    end

  when "presence"
    pres_type = raw.match(/type=['"]([^'"]+)['"]/)&.[](1)&.downcase || ""

    if pres_type == "unavailable"
      sender = $xmpp_clients.find { |c| c[:ws] == ws }
      if sender
        broadcast_presence(ws, sender[:last_presence][:status], sender[:last_presence][:away], true)
      end
      return
    end

    away   = raw.include?("<show>")
    status = raw.match(/<status>(.*?)<\/status>/m)&.[](1) || "{}"

    unless registered
      unless account_id.empty? || jid.empty?
        $xmpp_clients << {
          ws: ws, account_id: account_id, jid: jid, id: bare_jid,
          last_presence: { away: false, status: "{}", offline: false }
        }
        yield({ registered: true })
      end
    end

    broadcast_presence(ws, status, away, false)

  when "close"
    remove_xmpp_client(ws)
    ws.close
  end
rescue => e
  # silent
end
