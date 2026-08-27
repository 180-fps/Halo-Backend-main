require "sinatra/base"
require "json"
require "time"
require_relative "../utils/helpers"

STATS_FILE = File.join(__dir__, "../responses/profiles/stats.json")

def load_stats
  return JSON.parse(File.read(STATS_FILE)) if File.exist?(STATS_FILE)
  {}
rescue
  {}
end

def save_stats(data)
  File.write(STATS_FILE, JSON.generate(data))
rescue; end

def get_player_stats(account_id)
  stats = load_stats
  stats[account_id] ||= {
    "playlist_defaultsolo"  => { "kills" => 0, "matches" => 0, "wins" => 0, "top10" => 0, "top25" => 0, "score" => 0 },
    "playlist_defaultduo"   => { "kills" => 0, "matches" => 0, "wins" => 0, "top5"  => 0, "top12" => 0, "score" => 0 },
    "playlist_defaultsquad" => { "kills" => 0, "matches" => 0, "wins" => 0, "top3"  => 0, "top6"  => 0, "score" => 0 }
  }
  stats[account_id]
end

def build_stats_response(account_id, player_stats)
  s  = player_stats
  solo   = s["playlist_defaultsolo"]   || {}
  duo    = s["playlist_defaultduo"]    || {}
  squad  = s["playlist_defaultsquad"]  || {}

  {
    "accountId" => account_id,
    "stats" => {
      "br_score_keyboardmouse_m0_playlist_DefaultSolo"          => solo["score"]   || 0,
      "br_score_keyboardmouse_m0_playlist_DefaultDuo"           => duo["score"]    || 0,
      "br_score_keyboardmouse_m0_playlist_DefaultSquad"         => squad["score"]  || 0,
      "br_kills_keyboardmouse_m0_playlist_DefaultSolo"          => solo["kills"]   || 0,
      "br_kills_keyboardmouse_m0_playlist_DefaultDuo"           => duo["kills"]    || 0,
      "br_kills_keyboardmouse_m0_playlist_DefaultSquad"         => squad["kills"]  || 0,
      "br_matchesplayed_keyboardmouse_m0_playlist_DefaultSolo"  => solo["matches"] || 0,
      "br_matchesplayed_keyboardmouse_m0_playlist_DefaultDuo"   => duo["matches"]  || 0,
      "br_matchesplayed_keyboardmouse_m0_playlist_DefaultSquad" => squad["matches"]|| 0,
      "br_placetop25_keyboardmouse_m0_playlist_DefaultSolo"     => solo["top25"]   || 0,
      "br_placetop12_keyboardmouse_m0_playlist_DefaultDuo"      => duo["top12"]    || 0,
      "br_placetop6_keyboardmouse_m0_playlist_DefaultSquad"     => squad["top6"]   || 0,
      "br_placetop10_keyboardmouse_m0_playlist_DefaultSolo"     => solo["top10"]   || 0,
      "br_placetop5_keyboardmouse_m0_playlist_DefaultDuo"       => duo["top5"]     || 0,
      "br_placetop3_keyboardmouse_m0_playlist_DefaultSquad"     => squad["top3"]   || 0,
      "br_placetop1_keyboardmouse_m0_playlist_DefaultSolo"      => solo["wins"]    || 0,
      "br_placetop1_keyboardmouse_m0_playlist_DefaultDuo"       => duo["wins"]     || 0,
      "br_placetop1_keyboardmouse_m0_playlist_DefaultSquad"     => squad["wins"]   || 0
    },
    "startTime" => Time.now.utc.to_i,
    "endTime"   => (Time.now.utc + 604800).to_i
  }
end

class StatsRoutes < Sinatra::Base
  before { content_type :json }

  get "/fortnite/api/statsv2/account/:accountId" do
    status 200
    player_stats = get_player_stats(params[:accountId])
    build_stats_response(params[:accountId], player_stats).to_json
  end

  get "/statsproxy/api/statsv2/account/:accountId" do
    status 200
    player_stats = get_player_stats(params[:accountId])
    build_stats_response(params[:accountId], player_stats).to_json
  end

  get "/fortnite/api/stats/accountId/:accountId/bulk/window/alltime" do
    status 200
    player_stats = get_player_stats(params[:accountId])
    build_stats_response(params[:accountId], player_stats).to_json
  end

  post "/statsproxy/api/statsv2/query" do
    status 200
    body_data = begin JSON.parse(request.body.read) rescue {} end
    owners = body_data["owners"] || []
    all_stats = load_stats
    owners.map do |id|
      ps = all_stats[id] || get_player_stats(id)
      build_stats_response(id, ps)
    end.to_json
  end

  post "/fortnite/api/statsv2/query" do
    status 200
    body_data = begin JSON.parse(request.body.read) rescue {} end
    owners = body_data["owners"] || []
    all_stats = load_stats
    owners.map do |id|
      ps = all_stats[id] || get_player_stats(id)
      build_stats_response(id, ps)
    end.to_json
  end

  get "/statsproxy/api/statsv2/leaderboards/:stat" do
    status 200
    stat = params[:stat].downcase
    all_stats = load_stats
    playlist = if stat.include?("solo") then "playlist_defaultsolo"
               elsif stat.include?("duo") then "playlist_defaultduo"
               else "playlist_defaultsquad"
               end

    entries = all_stats.map { |id, ps| { "account" => id, "value" => (ps.dig(playlist, "wins") || 0) } }
                       .sort_by { |e| -e["value"] }
                       .first(1000)
    { "entries" => entries, "maxSize" => 1000 }.to_json
  end

  post "/managers/stats/:sessionId/:username/:placement/:eliminations/:totalXP/:score" do
    username    = params[:username]
    placement   = params[:placement].to_i
    eliminations = params[:eliminations].to_i
    total_xp    = params[:totalXP].to_i
    score_val   = params[:score].to_i

    return status(400) && "Invalid totalXP" if total_xp == 0

    playlist = "playlist_defaultsolo"

    all_stats = load_stats
    all_stats[username] ||= get_player_stats(username)
    ps = all_stats[username]
    pl = ps[playlist] ||= { "kills" => 0, "matches" => 0, "wins" => 0, "top10" => 0, "top25" => 0, "score" => 0 }

    pl["kills"]   += eliminations
    pl["matches"] += 1
    pl["score"]   += score_val
    pl["wins"]    += 1 if placement == 1
    pl["top10"]   += 1 if placement <= 10
    pl["top25"]   += 1 if placement <= 25

    save_stats(all_stats)
    status 200
    "Success"
  end
end
