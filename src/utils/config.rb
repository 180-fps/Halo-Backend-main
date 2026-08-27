require "inifile"

CONFIG_FILE = File.join(__dir__, "../../Config/config.ini")

def load_config
  IniFile.load(CONFIG_FILE)
rescue
  {}
end

$config = load_config
$display_name = $config["Config"]["displayName"] rescue "ReverseServer"
$use_config_display_name = ($config["Config"]["bUseConfigDisplayName"].to_s.downcase == "true") rescue false
$game_ip = $config["GameServer"]["ip"] rescue "127.0.0.1"
$game_port = ($config["GameServer"]["port"] || 7777).to_i rescue 7777
$completed_quests = ($config["Profile"]["bCompletedSeasonalQuests"].to_s.downcase == "true") rescue false
