require "sinatra/base"
require "json"
require_relative "../utils/helpers"

CATALOG_PATH   = File.join(__dir__, "../responses/catalog.json")
SAC_PATH       = File.join(__dir__, "../responses/SAC.json")
KEYCHAIN_PATH  = File.join(__dir__, "../responses/keychain.json")

class StorefrontRoutes < Sinatra::Base
  before do
    content_type :json
  end

  get "/fortnite/api/storefront/v2/catalog" do
    status 200
    info = get_version_info(request.user_agent)
    catalog = File.exist?(CATALOG_PATH) ? JSON.parse(File.read(CATALOG_PATH)) : { "storefronts" => [] }

    if info[:build] >= 30.10
      catalog = JSON.parse(JSON.generate(catalog).gsub('"Normal"', '"Size_1_x_2"'))
    end
    if info[:build] >= 30.20
      catalog = JSON.parse(JSON.generate(catalog).gsub('Game/Items/CardPacks/', 'SaveTheWorld/Items/CardPacks/'))
    end

    catalog.to_json
  end

  get "/fortnite/api/storefront/v2/keychain" do
    status 200
    File.exist?(KEYCHAIN_PATH) ? File.read(KEYCHAIN_PATH) : [].to_json
  end

  get "/catalog/api/shared/bulk/offers" do
    status 200
    {}.to_json
  end

  get "/affiliate/api/public/affiliates/slug/:slug" do
    status 200
    codes = File.exist?(SAC_PATH) ? JSON.parse(File.read(SAC_PATH)) : []
    match = codes.find { |c| c.downcase == params[:slug].downcase }
    if match
      { id: match, slug: match, displayName: match, status: "ACTIVE", verified: false }.to_json
    else
      status 404
      {}.to_json
    end
  end
end
