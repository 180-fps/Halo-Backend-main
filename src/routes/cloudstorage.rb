require "sinatra/base"
require "json"
require "digest"
require "time"

CLOUDSTORAGE_DIR = File.join(__dir__, "../CloudStorage")
CLIENT_SETTINGS_DIR = File.join(ENV["LOCALAPPDATA"] || __dir__, "ClientSettings")
Dir.mkdir(CLIENT_SETTINGS_DIR) unless Dir.exist?(CLIENT_SETTINGS_DIR)

class CloudStorageRoutes < Sinatra::Base
  get "/fortnite/api/cloudstorage/system" do
    content_type :json
    status 200

    files = Dir.glob(File.join(CLOUDSTORAGE_DIR, "*.ini")).map do |path|
      content = File.read(path, encoding: "utf-8")
      stat    = File.stat(path)
      name    = File.basename(path)
      {
        uniqueFilename: name,
        filename: name,
        hash:    Digest::SHA1.hexdigest(content),
        hash256: Digest::SHA256.hexdigest(content),
        length:  content.bytesize,
        contentType: "application/octet-stream",
        uploaded: stat.mtime.utc.iso8601(3),
        storageType: "S3",
        storageIds: {},
        doNotCache: true
      }
    end

    files.to_json
  end

  get "/fortnite/api/cloudstorage/system/:file" do
    path = File.join(CLOUDSTORAGE_DIR, params[:file])
    if File.exist?(path)
      content_type "application/octet-stream"
      status 200
      content = File.binread(path)
      if params[:file] == "DefaultEngine.ini"
        content += "\n[ConsoleVariables]\nnet.AllowEncryption=0\n"
      end
      content
    else
      status 200
      ""
    end
  end

  get "/fortnite/api/cloudstorage/user/:accountId" do
    content_type :json
    status 200

    cl = build_id_from_ua(request.user_agent)
    file = File.join(CLIENT_SETTINGS_DIR, "ClientSettings-#{cl}.Sav")

    if File.exist?(file)
      content = File.read(file, encoding: "binary")
      stat    = File.stat(file)
      [{
        uniqueFilename: "ClientSettings.Sav",
        filename: "ClientSettings.Sav",
        hash:    Digest::SHA1.hexdigest(content),
        hash256: Digest::SHA256.hexdigest(content),
        length:  content.bytesize,
        contentType: "application/octet-stream",
        uploaded: stat.mtime.utc.iso8601(3),
        storageType: "S3",
        storageIds: {},
        accountId: params[:accountId],
        doNotCache: true
      }].to_json
    else
      [].to_json
    end
  end

  get "/fortnite/api/cloudstorage/user/*/:file" do
    if params[:file].downcase != "clientsettings.sav"
      content_type :json
      return status(404) && { error: "file not found" }.to_json
    end

    cl   = build_id_from_ua(request.user_agent)
    path = File.join(CLIENT_SETTINGS_DIR, "ClientSettings-#{cl}.Sav")

    if File.exist?(path)
      content_type "application/octet-stream"
      status 200
      File.binread(path)
    else
      status 200
      ""
    end
  end

  put "/fortnite/api/cloudstorage/user/*/:file" do
    if params[:file].downcase != "clientsettings.sav"
      content_type :json
      return status(404) && { error: "file not found" }.to_json
    end

    cl   = build_id_from_ua(request.user_agent)
    path = File.join(CLIENT_SETTINGS_DIR, "ClientSettings-#{cl}.Sav")

    body_data = request.body.read
    File.binwrite(path, body_data)
    status 204
    ""
  end

  private

  def build_id_from_ua(ua)
    return "unknown" unless ua
    begin
      ua.split("-")[3].split(",")[0]
    rescue
      "unknown"
    end
  end
end
