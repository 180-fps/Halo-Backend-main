require "sinatra/base"
require "json"

module Errors
  def self.register(app)
    app.error do
      content_type :json
      status 500
      { status: "error", message: "Something went wrong!" }.to_json
    end

    app.not_found do
      content_type :json
      status 404
      { status: "error", message: "Route not found: #{request.request_method} #{request.path}" }.to_json
    end
  end
end
