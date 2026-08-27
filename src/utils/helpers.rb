require "securerandom"
require "time"

def make_id
  SecureRandom.uuid
end

def get_version_info(user_agent)
  info = { season: 2, build: 2.0, cl: "", lobby: "LobbyWinterDecor" }
  return info unless user_agent

  cl = ""
  begin
    build_id = user_agent.split("-")[3].split(",")[0]
    cl = build_id if build_id =~ /^\d+$/
  rescue
    begin
      build_id = user_agent.split("-")[1].split("+")[0]
      cl = build_id if build_id =~ /^\d+$/
    rescue; end
  end

  begin
    build_str = user_agent.split("Release-")[1].split("-")[0]
    parts = build_str.split(".")
    if parts.length == 3
      build_str = "#{parts[0]}.#{parts[1]}#{parts[2]}"
    end
    season = build_str.split(".")[0].to_i
    build  = build_str.to_f
    info = { season: season, build: build, cl: cl, lobby: "LobbySeason#{season}" }
  rescue
    info[:cl] = cl
  end

  info
end
