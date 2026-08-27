require "faye/websocket"
require "eventmachine"
require "json"
require "securerandom"
require_relative "../utils/helpers"
require_relative "../utils/config"

FILL_SIZE      = 100
POOL_TIMEOUT   = 8

$mm_pools = {}

def mm_bucket_key(bucket_id)
  return "default:default" unless bucket_id
  parts    = bucket_id.to_s.split(":")
  region   = parts[1] || "EU"
  playlist = parts[2] || "default"
  "#{region}:#{playlist}"
end

def mm_safe_send(ws, data)
  ws.send(JSON.generate(data)) if ws.ready_state == Faye::WebSocket::OPEN
rescue; end

def mm_dispatch_pool(bucket_key)
  pool = $mm_pools.delete(bucket_key)
  return unless pool
  pool[:timer]&.cancel
  session_id = SecureRandom.hex(16)
  match_id   = SecureRandom.hex(16)
  pool[:clients].each do |ws|
    next unless ws.ready_state == Faye::WebSocket::OPEN
    EM.add_timer(0.3)  { mm_safe_send(ws, { payload: { ticketId: SecureRandom.hex(8), queuedPlayers: 0, estimatedWaitSec: 0, status: {}, state: "Queued" }, name: "StatusUpdate" }) }
    EM.add_timer(1.8)  { mm_safe_send(ws, { payload: { matchId: match_id, state: "SessionAssignment" }, name: "StatusUpdate" }) }
    EM.add_timer(2.8)  { mm_safe_send(ws, { payload: { matchId: match_id, sessionId: session_id, joinDelaySec: 1 }, name: "Play" }) }
  end
end

class MatchmakerWsApp
  def self.call(env)
    return [404, {}, ["Not a WebSocket"]] unless Faye::WebSocket.websocket?(env)

    ws = Faye::WebSocket.new(env, nil, ping: 15)

    cookie_header = env["HTTP_COOKIE"] || ""
    match = cookie_header.match(/currentbuildUniqueId=([^;]+)/)
    bucket_id  = match ? CGI.unescape(match[1]) : "default"
    bucket_key = mm_bucket_key(bucket_id)

    pool = $mm_pools[bucket_key] ||= { clients: [], timer: nil }
    pool[:clients] << ws

    ws.on :open do
      mm_safe_send(ws, { payload: { state: "Connecting" }, name: "StatusUpdate" })
      EM.add_timer(0.4) { mm_safe_send(ws, { payload: { totalPlayers: pool[:clients].size, connectedPlayers: pool[:clients].size, state: "Waiting" }, name: "StatusUpdate" }) }
    end

    ws.on :close do
      pool = $mm_pools[bucket_key]
      if pool
        pool[:clients].delete(ws)
        if pool[:clients].empty?
          pool[:timer]&.cancel
          $mm_pools.delete(bucket_key)
        end
      end
    end

    if pool[:clients].size >= FILL_SIZE
      pool[:timer]&.cancel
      mm_dispatch_pool(bucket_key)
    else
      pool[:timer]&.cancel
      pool[:timer] = EM.add_timer(POOL_TIMEOUT) { mm_dispatch_pool(bucket_key) }
    end

    ws.rack_response
  end
end
