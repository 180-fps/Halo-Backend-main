require "sinatra/base"
require "json"

class LightswitchRoutes < Sinatra::Base
  get "/lightswitch/api/service/Fortnite/status" do
    content_type :json
    status 200
    {
      serviceInstanceId: "fortnite",
      status: "UP",
      message: "Fortnite is online",
      maintenanceUri: nil,
      overrideCatalogIds: ["a7f138b2e51945ffbfdacc1af0541053"],
      allowedActions: [],
      banned: false,
      launcherInfoDTO: {
        appName: "Fortnite",
        catalogItemId: "4fe75bbc5a674f4f9b356b5c90567da5",
        namespace: "fn"
      }
    }.to_json
  end

  get "/lightswitch/api/service/bulk/status" do
    content_type :json
    status 200
    [{
      serviceInstanceId: "fortnite",
      status: "UP",
      message: "fortnite is up.",
      maintenanceUri: nil,
      overrideCatalogIds: ["a7f138b2e51945ffbfdacc1af0541053"],
      allowedActions: ["PLAY", "DOWNLOAD"],
      banned: false,
      launcherInfoDTO: {
        appName: "Fortnite",
        catalogItemId: "4fe75bbc5a674f4f9b356b5c90567da5",
        namespace: "fn"
      }
    }].to_json
  end
end
