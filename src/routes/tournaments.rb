require "sinatra/base"
require "json"
require_relative "../utils/helpers"

TOURNAMENT_DIR = File.join(__dir__, "../responses/Athena/Tournament")

class TournamentRoutes < Sinatra::Base
  get "/fortnite/api/game/v2/events/tournamentandhistory/*" do
    content_type :json
    status 200
    path = File.join(TOURNAMENT_DIR, "tournamentandhistory.json")
    File.exist?(path) ? File.read(path) : {}.to_json
  end

  get "/fortnite/api/statsv2/account/:accountId" do
    content_type :json
    status 200
    { startTime: 0, endTime: 0, stats: {}, accountId: params[:accountId] }.to_json
  end

  get "/api/v1/events/Fortnite/download/:accountId" do
    content_type :json
    status 200
    path = File.join(TOURNAMENT_DIR, "tournament.json")
    return {}.to_json unless File.exist?(path)
    tournament = JSON.parse(File.read(path))
    tournament["player"]["accountId"] = params[:accountId] rescue nil
    info = get_version_info(request.user_agent)
    if info[:season] >= 33
      date = (Time.now - 86400).strftime("%Y-%m-%d")
      begin
        tournament["events"][0]["beginTime"]  = tournament["events"][0]["beginTime"].sub(/^\d{4}-\d{2}-\d{2}/, date)
        tournament["events"][0]["endTime"]    = tournament["events"][0]["endTime"].sub(/^\d{4}-\d{2}-\d{2}/, date)
        tournament["events"][0]["eventWindows"][0]["beginTime"]        = tournament["events"][0]["eventWindows"][0]["beginTime"].sub(/^\d{4}-\d{2}-\d{2}/, date)
        tournament["events"][0]["eventWindows"][0]["countdownBeginTime"] = tournament["events"][0]["eventWindows"][0]["countdownBeginTime"].sub(/^\d{4}-\d{2}-\d{2}/, date)
        tournament["events"][0]["eventWindows"][0]["endTime"]          = tournament["events"][0]["eventWindows"][0]["endTime"].sub(/^\d{4}-\d{2}-\d{2}/, date)
      rescue; end
    end
    tournament.to_json
  end

  get "/api/v1/events/Fortnite/:eventId/history/:accountId" do
    content_type :json
    status 200
    path = File.join(TOURNAMENT_DIR, "history.json")
    return [].to_json unless File.exist?(path)
    history = JSON.parse(File.read(path))
    history[0]["scoreKey"]["eventId"] = params[:eventId] rescue nil
    history[0]["teamId"]              = params[:accountId] rescue nil
    history[0]["teamAccountIds"]      = [params[:accountId]] rescue nil
    history.to_json
  end

  get "/api/v1/players/Fortnite/tokens" do
    content_type :json
    status 200
    path = File.join(TOURNAMENT_DIR, "tournament.json")
    return { accounts: [] }.to_json unless File.exist?(path)
    tournament   = JSON.parse(File.read(path))
    account_ids  = (params[:teamAccountIds] || "").split(",")
    accounts     = account_ids.map { |id| { accountId: id, tokens: tournament.dig("player", "tokens") || [] } }
    { accounts: accounts }.to_json
  end

  get "/api/v1/leaderboards/Fortnite/:eventId/:eventWindowId/:accountId" do
    content_type :json
    status 200
    path = File.join(TOURNAMENT_DIR, "leaderboard.json")
    return {}.to_json unless File.exist?(path)
    lb = JSON.parse(File.read(path))
    lb["eventId"]       = params[:eventId]
    lb["eventWindowId"] = params[:eventWindowId]
    template = lb.delete("entryTemplate") || {}
    names = ["Lawin", "PRO100KatYT", "TI93", "Playeereq", "Matteoki", params[:accountId]]
    names.unshift(params[:accountId])
    lb["entries"] = names.each_with_index.map do |name, i|
      entry = template.dup
      entry["teamAccountIds"] = [name]
      entry["teamId"]         = name
      entry["score"]          = 69 - i
      entry["pointsEarned"]   = 69 - i
      entry["rank"]           = i + 1
      entry
    end
    lb.to_json
  end

  get "/fortnite/api/game/v2/leaderboards/cohort/:accountId" do
    content_type :json
    status 200
    { accountId: params[:accountId], cohortAccounts: [params[:accountId], "Lawin", "TI93"], expiresAt: "9999-12-31T00:00:00.000Z", playlist: params[:playlist] }.to_json
  end

  post "/fortnite/api/leaderboards/type/group/stat/:statName/window/:statWindow" do
    content_type :json
    status 200
    ids = JSON.parse(request.body.read) rescue []
    entries = ids.map { |id| { accountId: id, value: rand(1..68) } }
    { entries: entries, statName: params[:statName], statWindow: params[:statWindow] }.to_json
  end

  post "/fortnite/api/leaderboards/type/global/stat/:statName/window/:statWindow" do
    content_type :json
    status 200
    names_path = File.join(__dir__, "../responses/Campaign/heroNames.json")
    names = File.exist?(names_path) ? JSON.parse(File.read(names_path)) : []
    entries = names.map { |n| { accountId: n, value: rand(1..68) } }
    { entries: entries, statName: params[:statName], statWindow: params[:statWindow] }.to_json
  end
end
