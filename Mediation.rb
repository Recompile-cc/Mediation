$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'serialport'
require 'discordrb'
require 'json'
require 'sqlite3'
require 'rumoji'
require 'Term.rb'

$config = JSON.parse(File.read('config.json'))
dbFile = "/home/pi/Messages-#{$config["discord"]["server_id"].to_s}.db"
$dbot = Discordrb::Bot.new token: $config["discord"]["bot_token"]
$sp = SerialPort.new($config["terminal"]["port"].to_s, $config["terminal"]["baud_rate"].to_i)

at_exit do
  puts "Closing..."
  if $dbot.connected?
    $dbot.stop
  end
  # conf = File.new('config.json', 'w')
  # f.write("#{$config.to_json}\n")
  # f.close
end

if File.exist?(dbFile)
  File.delete(dbFile)
end
$db = setup_database(dbFile)

$dbot.ready do |event|
  puts "Connected!"
  refresh($sp, $dbot, $db, $config["preferences"]["channel"].to_s, $config["discord"]["server_id"].to_s)
end

$dbot.message() do |event|
  if event.server.id == $config["discord"]["server_id"].to_i
    message = fix_text(event.message.content.to_s)
    time = event.message.timestamp.to_s
    push_message($db, message, event.author.id.to_s, event.channel.id.to_s, time)
    if (event.channel.id.to_s == $config["preferences"]["channel"].to_s)
      # New message is on currently displayed channel
      print_message($sp, message, get_name($dbot, $config["discord"]["server_id"].to_s, event.author.id.to_s))
    end
  end
end

$dbot.run