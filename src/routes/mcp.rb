require "sinatra/base"
require "json"
require "fileutils"
require "securerandom"
require "time"
require_relative "../utils/helpers"
require_relative "../utils/config"

PROFILES_DIR  = File.join(__dir__, "../responses/profiles")
RESPONSES_DIR = File.join(__dir__, "../responses")

Dir.mkdir(PROFILES_DIR) unless Dir.exist?(PROFILES_DIR)

$profile_cache = {}

def make_id
  SecureRandom.uuid
end

def load_profile(profile_id, account_id)
  cache_key = "#{account_id}_#{profile_id}"
  return JSON.parse($profile_cache[cache_key].to_json) if $profile_cache[cache_key]

  path = File.join(PROFILES_DIR, "#{profile_id}.json")
  data = if File.exist?(path)
    raw = File.read(path, encoding: "utf-8").sub(/\A\xEF\xBB\xBF/, "")
    JSON.parse(raw)
  else
    build_empty_profile(profile_id, account_id)
  end

  $profile_cache[cache_key] = data
  JSON.parse(data.to_json)
rescue
  build_empty_profile(profile_id, account_id)
end

def save_profile(profile_id, account_id, profile)
  cache_key = "#{account_id}_#{profile_id}"
  $profile_cache[cache_key] = JSON.parse(profile.to_json)
  path = File.join(PROFILES_DIR, "#{profile_id}.json")
  Thread.new { File.write(path, JSON.generate(profile)) rescue nil }
end

def build_empty_profile(profile_id, account_id)
  now = Time.now.utc.iso8601(3)
  src = File.join(RESPONSES_DIR, "#{profile_id}.json")
  if File.exist?(src)
    data = JSON.parse(File.read(src, encoding: "utf-8").sub(/\A\xEF\xBB\xBF/, ""))
    data["accountId"] = account_id
    data["created"]   = now
    save_profile(profile_id, account_id, data)
    return data
  end
  { "created" => now, "updated" => now, "rvn" => 1, "wipeNumber" => 1,
    "accountId" => account_id, "profileId" => profile_id, "version" => "no_version",
    "items" => {}, "stats" => { "attributes" => {} }, "commandRevision" => 0 }
end

def bump(profile)
  profile["rvn"] = (profile["rvn"] || 0) + 1
  profile["commandRevision"] = (profile["commandRevision"] || 0) + 1
  profile["updated"] = Time.now.utc.iso8601(3)
end

def mcp_resp(profile, profile_id, changes = nil, multi = nil)
  rvn = profile["rvn"] || 1
  out = {
    "profileRevision"            => rvn,
    "profileId"                  => profile_id,
    "profileChangesBaseRevision" => rvn,
    "profileChanges"             => changes || [{ "changeType" => "fullProfileUpdate", "profile" => profile }],
    "profileCommandRevision"     => profile["commandRevision"] || rvn,
    "serverTime"                 => Time.now.utc.iso8601(3),
    "responseVersion"            => 1
  }
  out["multiUpdate"] = multi if multi
  out
end

class McpRoutes < Sinatra::Base
  before { content_type :json }

  post "/fortnite/api/game/v2/profile/:accountId/client/:operation" do
    account_id = params[:accountId]
    operation  = params[:operation]
    profile_id = params[:profileId] || "athena"
    query_rvn  = (params[:rvn] || -1).to_i

    profile = load_profile(profile_id, account_id)
    profile["accountId"] = account_id
    profile["items"]  ||= {}
    profile["stats"]  ||= {}
    profile["stats"]["attributes"] ||= {}

    base_rvn = profile["rvn"] || 1
    body = begin JSON.parse(request.body.read) rescue {} end

    changes = dispatch(operation, profile, profile_id, account_id, body, request.user_agent)

    if query_rvn != base_rvn || changes.nil?
      changes = [{ "changeType" => "fullProfileUpdate", "profile" => profile }]
    end

    save_profile(profile_id, account_id, profile)
    status 200
    mcp_resp(profile, profile_id, changes).to_json
  end

  post "/fortnite/api/game/v2/profile/:accountId/dedicated_server/:operation" do
    profile_id = params[:profileId] || "athena"
    status 200
    { "profileRevision" => 1, "profileId" => profile_id,
      "profileChangesBaseRevision" => 0, "profileChanges" => [],
      "serverTime" => Time.now.utc.iso8601(3),
      "profileCommandRevision" => 1, "responseVersion" => 1 }.to_json
  end

  private

  def dispatch(op, profile, profile_id, account_id, body, ua)
    case op
    when "QueryProfile", "GetMcpTimeId", "GetMcpTimeForLogin"
      patch_season(profile, profile_id)
      nil

    when "ClientQuestLogin"
      inject_quests(profile, profile_id)
      nil

    when "SetCosmeticLockerSlot"
      op_locker_slot(profile, body)

    when "EquipBattleRoyaleCustomization"
      op_equip(profile, body)

    when "SetItemFavoriteStatusBatch", "SetItemFavoriteStatus"
      op_favorite(profile, body)

    when "MarkItemSeen"
      op_mark_seen(profile, body)

    when "SetBannerIcon"
      profile["stats"]["attributes"]["banner_icon"] = body["homebaseBannerIconId"] || ""
      bump(profile)
      [{ "changeType" => "statModified", "name" => "banner_icon", "value" => profile["stats"]["attributes"]["banner_icon"] }]

    when "SetBannerColor"
      profile["stats"]["attributes"]["banner_color"] = body["homebaseBannerColorId"] || ""
      bump(profile)
      [{ "changeType" => "statModified", "name" => "banner_color", "value" => profile["stats"]["attributes"]["banner_color"] }]

    when "SetBattleRoyaleBanner"
      op_battle_banner(profile, body, account_id)

    when "SetCosmeticLockerBanner"
      op_locker_banner(profile, body)

    when "SetCosmeticLockerName"
      op_locker_name(profile, body)

    when "PurchaseCatalogEntry"
      op_purchase(profile, body, account_id)

    when "RefundMtxPurchase"
      op_refund(profile, body)

    when "GiftCatalogEntry"
      op_gift(profile, body, account_id)

    when "SetReceiveGiftsEnabled"
      val = body["bReceiveGifts"] == true
      profile["stats"]["attributes"]["allowed_to_receive_gifts"] = val
      bump(profile)
      [{ "changeType" => "statModified", "name" => "allowed_to_receive_gifts", "value" => val }]

    when "RemoveGiftBox"
      op_remove_gift(profile, body)

    when "FortRerollDailyQuest"
      op_reroll_quest(profile, body)

    when "AthenaPinQuest"
      profile["stats"]["attributes"]["pinned_quest"] = body["pinnedQuest"] || ""
      bump(profile)
      [{ "changeType" => "statModified", "name" => "pinned_quest", "value" => profile["stats"]["attributes"]["pinned_quest"] }]

    when "SetPartyAssistQuest"
      profile["stats"]["attributes"]["party_assist_quest"] = body["questToPinAsPartyAssist"] || ""
      bump(profile)
      [{ "changeType" => "statModified", "name" => "party_assist_quest", "value" => profile["stats"]["attributes"]["party_assist_quest"] }]

    when "SetAffiliateName"
      op_affiliate(profile, body)

    when "UpdateQuestClientObjectives"
      op_update_quest_objectives(profile, body)

    when "MarkNewQuestNotificationSent"
      op_mark_quest_notification(profile, body)

    when "UnlockRewardNode"
      op_winterfest(profile, body, ua)

    when "PurchaseBattlePassTiers"
      op_buy_battlepass(profile, body, ua)

    when "CopyCosmeticLoadout", "DeleteCosmeticLoadout",
         "RefreshExpeditions", "IncrementNamedCounterStat",
         "SetHardcoreModifier", "SetMtxPlatform",
         "BulkEquipBattleRoyaleCustomization", "ClaimMfaEnabled",
         "ReadActivePurchaseLimitingEventInstancesForAccount"
      nil

    else
      nil
    end
  rescue => e
    puts "[MCP] #{op} error: #{e.message}"
    nil
  end

  def patch_season(profile, profile_id)
    return unless profile_id == "athena"
    path = File.join(RESPONSES_DIR, "Athena/SeasonData.json")
    return unless File.exist?(path)
    sd     = JSON.parse(File.read(path))
    season = (ENV["SEASON"] || "17").to_i
    attrs  = profile["stats"]["attributes"]
    attrs["season_num"] = season
    s = sd["Season#{season}"]
    return unless s
    attrs["book_purchased"]            = s["battlePassPurchased"]
    attrs["book_level"]                = s["battlePassTier"]
    attrs["season_match_boost"]        = s["battlePassXPBoost"]
    attrs["season_friend_match_boost"] = s["battlePassXPFriendBoost"]
  rescue; end

  def inject_quests(profile, profile_id)
    return unless profile_id == "athena"
    path = File.join(RESPONSES_DIR, "Athena/quests.json")
    return unless File.exist?(path)
    qdata  = JSON.parse(File.read(path))
    season = (ENV["SEASON"] || "17").to_i
    now    = Time.now.utc.iso8601(3)

    daily = qdata["Daily"] || []
    existing = profile["items"].values.count { |i| i["templateId"]&.match?(/Quest:AthenaDaily/i) }
    if existing < 3
      daily.first(3 - existing).each do |q|
        profile["items"][make_id] = make_quest_item(q, now)
      end
    end

    skey     = "Season%02d" % season
    seasonal = qdata[skey] || {}
    done     = $completed_quests

    (seasonal["ChallengeBundleSchedules"] || {}).each do |id, d|
      next if profile["items"][id]
      profile["items"][id] = { "templateId" => d["templateId"], "attributes" => {
        "granted_bundles" => d["granted_bundles"] || [], "has_unlock_by_quest" => false,
        "num_granted_bundle_ids" => (d["granted_bundles"] || []).length,
        "level" => -1, "item_seen" => true, "favorite" => false, "creation_time" => now
      }, "quantity" => 1 }
    end

    (seasonal["ChallengeBundles"] || {}).each do |id, d|
      next if profile["items"][id]
      granted = d["grantedquestinstanceids"] || []
      profile["items"][id] = { "templateId" => d["templateId"], "attributes" => {
        "has_unlock_by_quest" => false, "grantedquestinstanceids" => granted,
        "num_granted_bundle_ids" => granted.length,
        "challenge_bundle_schedule_id" => d["challenge_bundle_schedule_id"] || "",
        "level" => -1, "item_seen" => true, "favorite" => false, "creation_time" => now,
        "completion_rewards" => d["completionRewards"] || {}
      }, "quantity" => 1 }
    end

    (seasonal["Quests"] || {}).each do |id, d|
      next if profile["items"][id]
      state = done ? "Completed" : "Active"
      obj   = {}
      (d["objectives"] || {}).each { |k, v| obj["completion_#{k}"] = done ? v : 0 }
      profile["items"][id] = { "templateId" => d["templateId"], "attributes" => {
        "creation_time" => now, "level" => -1, "item_seen" => done,
        "sent_new_notification" => done, "xp_reward_scalar" => 1,
        "quest_state" => state, "last_state_change_time" => now,
        "challenge_bundle_id" => d["challenge_bundle_id"] || "",
        "max_level_bonus" => 0, "xp" => 0, "favorite" => false
      }.merge(obj), "quantity" => 1 }
    end

    bump(profile)
  rescue; end

  def make_quest_item(q, now)
    item = { "templateId" => q["templateId"], "attributes" => {
      "creation_time" => now, "level" => -1, "item_seen" => false,
      "sent_new_notification" => false, "xp_reward_scalar" => 1,
      "quest_state" => "Active", "last_state_change_time" => now,
      "max_level_bonus" => 0, "xp" => 0, "favorite" => false
    }, "quantity" => 1 }
    (q["objectives"] || []).each { |obj| item["attributes"]["completion_#{obj.downcase}"] = 0 }
    item
  end

  def op_locker_slot(profile, body)
    slot_name    = body["slotName"]           || ""
    item_to_slot = body["itemToSlot"]         || ""
    idx          = (body["indexWithinSlot"] || 0).to_i
    variants     = body["variantUpdates"]     || []

    locker_key, locker = profile["items"].find { |_, v| v["templateId"]&.start_with?("CosmeticLocker:cosmeticlocker_athena") }
    unless locker
      locker_key = profile["items"].keys.find { |k| profile["items"][k]["templateId"]&.include?("CosmeticLocker") }
      locker     = profile["items"][locker_key] if locker_key
    end
    return [] unless locker && !slot_name.empty?

    locker["attributes"]["locker_slots_data"] ||= { "slots" => {} }
    slots = locker["attributes"]["locker_slots_data"]["slots"] ||= {}
    slots[slot_name] ||= { "items" => [], "activeVariants" => [] }
    slot = slots[slot_name]
    slot["items"]    ||= []
    slot["items"][idx] = item_to_slot
    if variants.any?
      slot["activeVariants"]    ||= []
      slot["activeVariants"][idx] = variants
    end
    bump(profile)
    [{ "changeType" => "itemAttrChanged", "itemId" => locker_key,
       "attributeName" => "locker_slots_data",
       "attributeValue" => locker["attributes"]["locker_slots_data"] }]
  rescue; []
  end

  def op_equip(profile, body)
    slot = body["slotName"] || body["category"] || ""
    item = body["itemToSlot"] || body["itemId"] || ""
    idx  = (body["indexWithinSlot"] || body["categoryIndex"] || 0).to_i
    map  = {
      "Character" => "favorite_character", "Backpack" => "favorite_backpack",
      "Pickaxe" => "favorite_pickaxe", "Glider" => "favorite_glider",
      "SkyDiveContrail" => "favorite_skydivecontrail", "MusicPack" => "favorite_musicpack",
      "LoadingScreen" => "favorite_loadingscreen", "Dance" => "favorite_dance",
      "ItemWrap" => "favorite_itemwraps"
    }
    stat = map[slot]
    return [] unless stat
    attrs = profile["stats"]["attributes"]
    if %w[Dance ItemWrap].include?(slot)
      attrs[stat] ||= []
      attrs[stat][idx] = item
    else
      attrs[stat] = item
    end
    bump(profile)
    [{ "changeType" => "statModified", "name" => stat, "value" => attrs[stat] }]
  rescue; []
  end

  def op_favorite(profile, body)
    ids = body["itemIds"] || (body["itemId"] ? [body["itemId"]] : [])
    val = body["itemFavStatus"] == true || body["itemFavStatus"] == "true"
    changes = ids.filter_map do |id|
      next unless profile["items"][id]
      profile["items"][id]["attributes"]["favorite"] = val
      { "changeType" => "itemAttrChanged", "itemId" => id, "attributeName" => "favorite", "attributeValue" => val }
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_mark_seen(profile, body)
    changes = (body["itemIds"] || []).filter_map do |id|
      next unless profile["items"][id]
      profile["items"][id]["attributes"]["item_seen"] = true
      { "changeType" => "itemAttrChanged", "itemId" => id, "attributeName" => "item_seen", "attributeValue" => true }
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_locker_banner(profile, body)
    changes = []
    key, locker = profile["items"].find { |_, v| v["templateId"]&.include?("CosmeticLocker") }
    return changes unless locker
    if body["bannerIconTemplateName"]
      locker["attributes"]["banner_icon_template"] = body["bannerIconTemplateName"]
      changes << { "changeType" => "itemAttrChanged", "itemId" => key, "attributeName" => "banner_icon_template", "attributeValue" => body["bannerIconTemplateName"] }
    end
    if body["bannerColorTemplateName"]
      locker["attributes"]["banner_color_template"] = body["bannerColorTemplateName"]
      changes << { "changeType" => "itemAttrChanged", "itemId" => key, "attributeName" => "banner_color_template", "attributeValue" => body["bannerColorTemplateName"] }
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_locker_name(profile, body)
    locker_id = body["lockerItem"] || ""
    name      = body["name"]       || ""
    return [] unless profile["items"][locker_id]
    profile["items"][locker_id]["attributes"]["locker_name"] = name
    bump(profile)
    [{ "changeType" => "itemAttrChanged", "itemId" => locker_id, "attributeName" => "locker_name", "attributeValue" => name }]
  rescue; []
  end

  def op_battle_banner(profile, body, account_id)
    icon  = body["homebaseBannerIconId"]  || ""
    color = body["homebaseBannerColorId"] || ""
    profile["stats"]["attributes"]["banner_icon"]  = icon
    profile["stats"]["attributes"]["banner_color"] = color
    active_idx = profile["stats"]["attributes"]["active_loadout_index"] || 0
    loadouts   = profile["stats"]["attributes"]["loadouts"] || []
    active_key = loadouts[active_idx]
    if active_key && profile["items"][active_key]
      profile["items"][active_key]["attributes"]["banner_icon_template"]  = icon
      profile["items"][active_key]["attributes"]["banner_color_template"] = color
    end
    bump(profile)
    [{ "changeType" => "statModified", "name" => "banner_icon",  "value" => icon },
     { "changeType" => "statModified", "name" => "banner_color", "value" => color }]
  rescue; []
  end

  def op_purchase(profile, body, account_id)
    catalog_path = File.join(RESPONSES_DIR, "catalog.json")
    return [] unless File.exist?(catalog_path)
    catalog  = JSON.parse(File.read(catalog_path))
    offer_id = body["offerId"] || ""
    entry    = nil
    catalog["storefronts"]&.each { |sf| sf["catalogEntries"]&.each { |e| entry = e if e["offerId"] == offer_id } }
    return [] unless entry
    cc    = load_profile("common_core", account_id)
    price = (entry.dig("prices", 0, "finalPrice") || 0).to_i
    curr  = (cc.dig("items", "Currency", "quantity") || 0).to_i
    return [] if curr < price
    cc["items"]["Currency"]["quantity"] = curr - price
    bump(cc)
    save_profile("common_core", account_id, cc)
    changes = []
    (entry["itemGrants"] || []).each do |grant|
      id = make_id
      profile["items"][id] = { "templateId" => grant["templateId"],
        "attributes" => { "max_level_bonus" => 0, "level" => 1, "item_seen" => false,
          "xp" => 0, "variants" => [], "favorite" => false },
        "quantity" => (grant["quantity"] || 1).to_i }
      changes << { "changeType" => "itemAdded", "itemId" => id, "item" => profile["items"][id] }
    end
    bump(profile)
    changes
  rescue; []
  end

  def op_refund(profile, body)
    id = body["targetItemId"] || ""
    return [] unless profile["items"][id]
    profile["items"].delete(id)
    bump(profile)
    [{ "changeType" => "itemRemoved", "itemId" => id }]
  rescue; []
  end

  def op_gift(profile, body, account_id)
    catalog_path = File.join(RESPONSES_DIR, "catalog.json")
    return [] unless File.exist?(catalog_path)
    catalog  = JSON.parse(File.read(catalog_path))
    offer_id = body["offerId"] || ""
    entry    = nil
    catalog["storefronts"]&.each { |sf| sf["catalogEntries"]&.each { |e| entry = e if e["offerId"] == offer_id } }
    return [] unless entry
    receivers = body["receiverAccountIds"] || []
    return [] if receivers.empty? || receivers.length > 5
    cc    = load_profile("common_core", account_id)
    price = (entry.dig("prices", 0, "finalPrice") || 0).to_i * receivers.length
    curr  = (cc.dig("items", "Currency", "quantity") || 0).to_i
    return [] if curr < price
    cc["items"]["Currency"]["quantity"] = curr - price
    bump(cc)
    save_profile("common_core", account_id, cc)
    now     = Time.now.utc.iso8601(3)
    msg     = body["personalMessage"] || ""
    wrap    = body["giftWrapTemplateId"] || "GiftBox:gb_default"
    changes = []
    receivers.each do |receiver_id|
      rec_cc = load_profile("common_core", receiver_id)
      rec_cc["items"] ||= {}
      gift_id   = make_id
      loot_list = []
      (entry["itemGrants"] || []).each do |grant|
        item_id    = make_id
        rec_athena = load_profile("athena", receiver_id)
        rec_athena["items"] ||= {}
        rec_athena["items"][item_id] = { "templateId" => grant["templateId"],
          "attributes" => { "item_seen" => false, "variants" => [], "favorite" => false }, "quantity" => 1 }
        bump(rec_athena)
        save_profile("athena", receiver_id, rec_athena)
        loot_list << { "itemType" => grant["templateId"], "itemGuid" => item_id, "itemProfile" => "athena", "quantity" => 1 }
      end
      rec_cc["items"][gift_id] = { "templateId" => wrap,
        "attributes" => { "fromAccountId" => account_id, "lootList" => loot_list,
          "params" => { "userMessage" => msg }, "level" => 1, "giftedOn" => now }, "quantity" => 1 }
      bump(rec_cc)
      save_profile("common_core", receiver_id, rec_cc)
      send_xmpp_to(receiver_id, { "type" => "com.epicgames.gift.received", "payload" => {}, "timestamp" => now })
      changes << { "changeType" => "itemAdded", "itemId" => gift_id, "item" => rec_cc["items"][gift_id] } if receiver_id == account_id
    end
    changes
  rescue; []
  end

  def op_remove_gift(profile, body)
    ids     = [body["giftBoxItemId"], *(body["giftBoxItemIds"] || [])].compact
    changes = ids.filter_map do |id|
      next unless profile["items"][id]
      profile["items"].delete(id)
      { "changeType" => "itemRemoved", "itemId" => id }
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_reroll_quest(profile, body)
    quest_id = body["questId"] || ""
    return [] unless profile["items"][quest_id]
    rerolls = profile.dig("stats", "attributes", "quest_manager", "dailyQuestRerolls") || 0
    return [] if rerolls < 1
    path  = File.join(RESPONSES_DIR, "Athena/quests.json")
    daily = JSON.parse(File.read(path))["Daily"] rescue []
    used  = profile["items"].values.map { |i| i["templateId"] }
    pool  = daily.reject { |q| used.include?(q["templateId"]) }
    return [] if pool.empty?
    profile["stats"]["attributes"]["quest_manager"]["dailyQuestRerolls"] = rerolls - 1
    profile["items"].delete(quest_id)
    now    = Time.now.utc.iso8601(3)
    new_id = make_id
    profile["items"][new_id] = make_quest_item(pool.sample, now)
    bump(profile)
    [{ "changeType" => "itemRemoved", "itemId" => quest_id },
     { "changeType" => "itemAdded",   "itemId" => new_id, "item" => profile["items"][new_id] }]
  rescue; []
  end

  def op_affiliate(profile, body)
    path  = File.join(RESPONSES_DIR, "SAC.json")
    codes = File.exist?(path) ? JSON.parse(File.read(path)) : []
    name  = body["affiliateName"] || ""
    return [] unless name.empty? || codes.any? { |c| c.downcase == name.downcase }
    now   = Time.now.utc.iso8601(3)
    profile["stats"]["attributes"]["mtx_affiliate"]          = name
    profile["stats"]["attributes"]["mtx_affiliate_set_time"] = now
    bump(profile)
    [{ "changeType" => "statModified", "name" => "mtx_affiliate",          "value" => name },
     { "changeType" => "statModified", "name" => "mtx_affiliate_set_time", "value" => now  }]
  rescue; []
  end

  def op_update_quest_objectives(profile, body)
    changes = []
    (body["advance"] || []).each do |adv|
      stat_name = adv["statName"] || ""
      count     = adv["count"]    || 0
      profile["items"].each do |id, item|
        next unless item["templateId"]&.downcase&.start_with?("quest:")
        key = "completion_#{stat_name}"
        next unless item["attributes"].key?(key)
        item["attributes"][key] = count
        changes << { "changeType" => "itemAttrChanged", "itemId" => id, "attributeName" => key, "attributeValue" => count }
        if item["attributes"]["quest_state"]&.downcase != "claimed"
          all_done = item["attributes"].select { |k, _| k.start_with?("completion_") }.values.all? { |v| v.to_i > 0 }
          if all_done
            item["attributes"]["quest_state"] = "Claimed"
            changes << { "changeType" => "itemAttrChanged", "itemId" => id, "attributeName" => "quest_state", "attributeValue" => "Claimed" }
          end
        end
      end
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_mark_quest_notification(profile, body)
    changes = (body["itemIds"] || []).filter_map do |id|
      next unless profile["items"][id]
      profile["items"][id]["attributes"]["sent_new_notification"] = true
      { "changeType" => "itemAttrChanged", "itemId" => id, "attributeName" => "sent_new_notification", "attributeValue" => true }
    end
    bump(profile) unless changes.empty?
    changes
  rescue; []
  end

  def op_winterfest(profile, body, ua)
    path = File.join(RESPONSES_DIR, "Athena/winterfestRewards.json")
    return [] unless File.exist?(path) && body["nodeId"] && body["rewardGraphId"]
    info    = get_version_info(ua)
    rewards = JSON.parse(File.read(path)).dig("Season#{info[:season]}", body["nodeId"]) || []
    now     = Time.now.utc.iso8601(3)
    gift_id = make_id
    profile["items"][gift_id] = { "templateId" => "GiftBox:gb_winterfestreward",
      "attributes" => { "lootList" => [], "item_seen" => false, "fromAccountId" => "",
        "giftedOn" => now, "params" => { "winterfestGift" => "true" } }, "quantity" => 1 }
    changes = rewards.map do |r|
      id = make_id
      profile["items"][id] = { "templateId" => r,
        "attributes" => { "max_level_bonus" => 0, "level" => 1, "item_seen" => false,
          "xp" => 0, "variants" => [], "favorite" => false }, "quantity" => 1 }
      profile["items"][gift_id]["attributes"]["lootList"] << { "itemType" => r, "itemGuid" => id, "quantity" => 1 }
      { "changeType" => "itemAdded", "itemId" => id, "item" => profile["items"][id] }
    end
    changes << { "changeType" => "itemAdded", "itemId" => gift_id, "item" => profile["items"][gift_id] }
    bump(profile)
    changes
  rescue; []
  end

  def op_buy_battlepass(profile, body, ua)
    info   = get_version_info(ua)
    season = info[:season]
    return [] unless (2..10).include?(season)
    path = File.join(RESPONSES_DIR, "Athena/BattlePass/Season#{season}.json")
    return [] unless File.exist?(path)
    data    = JSON.parse(File.read(path))
    changes = (data["items"] || []).map do |item|
      id = make_id
      profile["items"][id] = { "templateId" => item["templateId"],
        "attributes" => { "max_level_bonus" => 0, "level" => 1, "item_seen" => false,
          "xp" => 0, "variants" => item["variants"] || [], "favorite" => false }, "quantity" => 1 }
      { "changeType" => "itemAdded", "itemId" => id, "item" => profile["items"][id] }
    end
    profile["stats"]["attributes"]["book_purchased"] = true
    profile["stats"]["attributes"]["book_level"]     = 100
    bump(profile)
    changes + [{ "changeType" => "statModified", "name" => "book_purchased", "value" => true },
               { "changeType" => "statModified", "name" => "book_level",     "value" => 100 }]
  rescue; []
  end

  def send_xmpp_to(account_id, body)
    return unless defined?($xmpp_clients) && $xmpp_clients
    target = $xmpp_clients.find { |c| c[:account_id] == account_id }
    return unless target
    msg = body.is_a?(String) ? body : body.to_json
    target[:ws].send(
      "<message from='xmpp-admin@prod.ol.epicgames.com' to='#{target[:jid]}' xmlns='jabber:client'><body>#{msg}</body></message>"
    ) rescue nil
  end
end
