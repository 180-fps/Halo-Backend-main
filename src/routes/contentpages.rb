require "sinatra/base"
require "json"
require_relative "../utils/helpers"

CONTENTPAGES_DATA = JSON.parse(File.read(File.join(__dir__, "../responses/contentpages.json")))
SPARK_TRACKS_PATH = File.join(__dir__, "../responses/Athena/sparkTracks.json")
SEASON_PASSES_PATH = File.join(__dir__, "../responses/Athena/seasonPasses.json")

def choose_translation(obj, lang)
  return obj unless obj.is_a?(Hash)
  if obj.key?(lang) || obj.key?("en")
    return obj[lang] || obj["en"]
  end
  obj.each_with_object({}) { |(k, v), h| h[k] = choose_translation(v, lang) }
end

class ContentPagesRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/content/api/pages/fortnite-game/spark-tracks" do
    status 200
    File.exist?(SPARK_TRACKS_PATH) ? File.read(SPARK_TRACKS_PATH) : {}.to_json
  end

  get "/content/api/pages/fortnite-game/seasonpasses" do
    status 200
    File.exist?(SEASON_PASSES_PATH) ? File.read(SEASON_PASSES_PATH) : {}.to_json
  end

  get "/content/api/pages/fortnite-game/radio-stations" do
    status 200
    {
      "_title" => "Radio Stations",
      "radioStationList" => { "_type" => "RadioStationList", "stations" => [] },
      "_noIndex" => false,
      "_locale" => "en-US"
    }.to_json
  end

  get "/content/api/pages/*" do
    info = get_version_info(request.user_agent)
    lang = (request.env["HTTP_ACCEPT_LANGUAGE"] || "en").split(",").first.split("-").first rescue "en"
    pages = JSON.parse(JSON.generate(CONTENTPAGES_DATA))

    begin
      season = "season#{info[:season]}#{info[:season] >= 21 ? '00' : ''}"
      bgs = pages.dig("dynamicbackgrounds", "backgrounds", "backgrounds")
      if bgs
        bgs[0]["stage"] = season
        bgs[1]["stage"] = season if bgs[1]
      end
    rescue; end

    status 200
    pages.to_json
  end
end
