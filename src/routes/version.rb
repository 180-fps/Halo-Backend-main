require "sinatra/base"
require "json"
require "time"
require_relative "../utils/helpers"
require_relative "../utils/config"

EVENTS_CONF = $config["Events"] rescue {}

def build_active_events(season, build)
  events = [
    { "eventType" => "EventFlag.Season#{season}",  "activeUntil" => "9999-01-01T00:00:00.000Z", "activeSince" => "2020-01-01T00:00:00.000Z" },
    { "eventType" => "EventFlag.LobbySeason#{season}", "activeUntil" => "9999-01-01T00:00:00.000Z", "activeSince" => "2020-01-01T00:00:00.000Z" }
  ]

  add = ->(type) { events << { "eventType" => "EventFlag.#{type}", "activeUntil" => "9999-01-01T00:00:00.000Z", "activeSince" => "2020-01-01T00:00:00.000Z" } }

  case season
  when 4
    add.("Blockbuster2018"); add.("Blockbuster2018Phase1")
    add.("Blockbuster2018Phase2") if build >= 4.3
    add.("Blockbuster2018Phase3") if build >= 4.4
    add.("Blockbuster2018Phase4") if build >= 4.5

    if EVENTS_CONF["bEnableGeodeEvent"] == "true"
      add.("GeodeEvent")
    end
    if EVENTS_CONF["bEnableS4OddityExecution"] == "true"
      add.("S4OddityExecution")
    end

  when 5
    add.("RoadTrip2018"); add.("Horde"); add.("Anniversary2018_BR")
    add.("BirthdayBattleBus") if build == 5.10
    if EVENTS_CONF["bEnableS5OddityExecution"] == "true"
      add.("S5OddityExecution")
    end

  when 6
    add.("LTM_Fortnitemares"); add.("LTM_LilKevin")
    if build >= 6.20
      add.("Fortnitemares"); add.("FortnitemaresPhase1"); add.("POI0")
    end
    if build >= 6.22
      add.("FortnitemaresPhase2")
    end
    if EVENTS_CONF["bEnableCubeLightning"] == "true"
      add.("CubeLightning")
    end
    if EVENTS_CONF["bEnableCubeLake"] == "true"
      add.("CubeLake")
    end

  when 7
    add.("Frostnite"); add.("LTM_14DaysOfFortnite"); add.("LTE_Festivus"); add.("LTM_WinterDeimos")

  when 8
    add.("Spring2019"); add.("Spring2019.Phase1"); add.("LTM_Ashton"); add.("LTM_Goose"); add.("LTM_HighStakes")
    add.("Spring2019.Phase2") if build >= 8.2

  when 9
    add.("Season9.Phase1"); add.("Anniversary2019_BR"); add.("LTM_14DaysOfSummer")
    add.("Season9.Phase2") if build >= 9.2

  when 10
    add.("Mayday"); add.("Season10.Phase2"); add.("Season10.Phase3"); add.("LTE_BlackMonday")
    add.("S10_Oak"); add.("S10_Mystery")
    (1..10).each { |i| add.("Season10_UrgentMission_#{i}") }

  when 11
    add.("LTE_CoinCollectXP"); add.("LTE_Fortnitemares2019"); add.("LTE_Galileo"); add.("LTE_WinterFest2019")
    add.("Starlight") if build >= 11.2
    if build == 11.31 || build == 11.40
      add.("Winterfest.Tree"); add.("LTE_WinterFest"); add.("HolidayDeco")
    end

  when 12
    add.("LTE_SpyGames"); add.("LTE_JerkyChallenges"); add.("LTE_Oro"); add.("LTE_StormTheAgency")

  when 14
    add.("LTE_Fortnitemares_2020")

  when 15
    (1..15).each { |i| add.("LTQ_S15_Legendary_Week_#{i.to_s.rjust(2, '0')}") }
    add.("Event_HiddenRole"); add.("Event_OperationSnowdown"); add.("Event_PlumRetro")

  when 16
    (1..12).each { |i| add.("LTQ_S16_Legendary_Week_#{i.to_s.rjust(2, '0')}") }
    add.("Event_NBA_Challenges"); add.("Event_Spire_Challenges")

  when 17
    add.("Event_TheMarch"); add.("Event_O2_Challenges"); add.("Event_CosmicSummer"); add.("Event_IslandGames")
    (1..9).each { |i| add.("LTQ_S17_Legendary_Week_#{i.to_s.rjust(2, '0')}") }

  when 19
    add.("LTE_WinterFest2021") if build == 19.01
  when 23
    add.("LTE_WinterFest2022") if build == 23.10
  end

  events
end

class VersionRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/fortnite/api/version" do
    status 200
    { app: "fortnite", serverDate: Time.now.utc.iso8601(3), overridePropertiesVersion: "unknown",
      cln: "17951730", build: "444", moduleName: "Fortnite-Core",
      buildDate: "2021-10-27T21:00:51.697Z", version: "18.30", branch: "Release-18.30" }.to_json
  end

  get "/fortnite/api/v2/versioncheck" do
    status 200
    { type: "NO_UPDATE" }.to_json
  end

  get "/fortnite/api/v2/versioncheck/:version" do
    status 200
    { type: "NO_UPDATE" }.to_json
  end

  get "/fortnite/api/versioncheck*" do
    status 200
    { type: "NO_UPDATE" }.to_json
  end

  get "/fortnite/api/calendar/v1/timeline" do
    info   = get_version_info(request.user_agent)
    season = info[:season]
    build  = info[:build]

    active_events = build_active_events(season, build)

    status 200
    {
      channels: {
        "client-matchmaking": { states: [], cacheExpire: "9999-01-01T00:00:00.000Z" },
        "client-events": {
          states: [
            {
              validFrom: "0001-01-01T00:00:00.000Z",
              activeEvents: active_events,
              state: {
                activeStorefronts: [],
                eventNamedWeights: {},
                seasonNumber: season.to_f,
                seasonTemplateId: "AthenaSeason:athenaseason#{season}",
                matchXpBonusPoints: 0,
                seasonBegin: "2020-01-01T00:00:00Z",
                seasonEnd: "9999-01-01T00:00:00Z",
                seasonDisplayedEnd: "9999-01-01T00:00:00Z",
                weeklyStoreEnd: "9999-01-01T00:00:00Z",
                stwEventStoreEnd: "9999-01-01T00:00:00.000Z",
                stwWeeklyStoreEnd: "9999-01-01T00:00:00.000Z",
                sectionStoreEnds: { Featured: "9999-01-01T00:00:00.000Z" },
                dailyStoreEnd: "9999-01-01T00:00:00Z"
              }
            }
          ],
          cacheExpire: "9999-01-01T00:00:00.000Z"
        }
      },
      eventsTimeOffsetHrs: 0,
      cacheIntervalMins: 10,
      currentTime: Time.now.utc.iso8601(3)
    }.to_json
  end
end
