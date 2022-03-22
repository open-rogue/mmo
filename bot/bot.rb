PREFIX = '^'
GAME_URL = "http://localhost:8000"
DISCORD_TOKEN = File.read("../discord_token.key").chomp
DISCORD_CLIENT_ID = File.read("../discord_client_id.key").chomp
FIREBASE_BASE_URI = "https://machin-dev.firebaseio.com"
FIREBASE_TOKEN = File.open("../firebase.json").read

puts "DISCORD_TOKEN=#{DISCORD_TOKEN}"
puts "DISCORD_CLIENT_ID=#{DISCORD_CLIENT_ID}"
puts "FIREBASE_TOKEN=#{FIREBASE_TOKEN}"

require 'bundler'
Bundler.setup(:default, :ci)

require 'rest-client'
require 'discordrb' # https://www.rubydoc.info/gems/discordrb/3.2.1/
require 'firebase'
require 'json'

$firebase = Firebase::Client.new(FIREBASE_BASE_URI, FIREBASE_TOKEN)

def get_rooms()
    body = $firebase.get("mmo/rooms").body
    return body == nil ? {} : body
end

def get_players()
    body = $firebase.get("mmo/players").body
    return body == nil ? {} : body
end

def add_user(uid, name, otp)
    return $firebase.set("mmo/players/#{uid}", {
        "name": name, "otp": otp, "room": "spawn", "x": 200, "y": 200,
        "dir": [0, 0], "isMoving": false, "animFrame": 0, "playerType": "man", 
        "inventory": {}
    }).success?
end

def refresh_otp(uid, otp)
    data = get_players()[uid]
    data["otp"] = otp
    return $firebase.set("mmo/players/#{uid}", data).success?
end

def format_standard(str); return "```\n#{str}\n```"; end
def format_success(str); return "```diff\n+ #{str}\n```"; end
def format_error(str); return "```diff\n- #{str}\n```"; end
def format_usage(str); return "Command usage: ``#{PREFIX}#{str}``"; end
def format_help(str); return "```markdown\n#{str}\n```"; end
def invite_link(uid, otp); "#{GAME_URL}/?uid=#{uid}&otp=#{otp}"; end

$bot = Discordrb::Bot.new(token: DISCORD_TOKEN, client_id: DISCORD_CLIENT_ID)

$bot.message(start_with: PREFIX + 'join') do |event|
    uid, otp = event.user.id.to_s, (0...8).map { (65 + rand(26)).chr }.join
    success = get_players().key?(uid) ? refresh_otp(uid, otp) : add_user(uid, event.author.display_name, otp)
    event.author.dm invite_link(uid, otp) if success
end

$bot.message(start_with: PREFIX + 'players') do |event|
    player_names = get_players().map { |uid, data| data["name"] }
    event.respond format_standard("Players (#{player_names.length}): [#{player_names.join(", ")}]")
end

$bot.message(start_with: PREFIX + 'rooms') do |event|
    room_ids = get_rooms().keys
    event.respond format_standard("Rooms (#{room_ids.length}): [#{room_ids.join(", ")}]")
end

$bot.run