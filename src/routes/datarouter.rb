require "sinatra/base"
require "json"

class DataRouterRoutes < Sinatra::Base
  post "/datarouter/api/v1/public/data" do
    content_type :json
    status 200
    { status: "OK", code: 200 }.to_json
  end
end
