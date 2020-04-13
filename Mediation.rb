puts "Loading Libraries..."
$LOAD_PATH.unshift(File.expand_path('../', __FILE__))
require 'serialport'
require 'discordrb'
require 'json'
require 'sqlite3'
require 'rumoji'
require 'Term.rb'

puts "Loading Program..."
$config = JSON.parse(File.read('config.json'))
dbFile = "/home/pi/Messages-#{$config["discord"]["server_id"].to_s}.db"
$dbot = Discordrb::Bot.new token: $config["discord"]["bot_token"]
$sp = SerialPort.new($config["terminal"]["port"].to_s, $config["terminal"]["baud_rate"].to_i)
$disable_incomming = false
$serverID = $config["discord"]["server_id"].to_i

at_exit do
  #Todo: fix saving prefs
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
  puts "Program Loaded"
  refresh($sp, $dbot, $db, $config["preferences"]["channel"].to_s, $config["discord"]["server_id"].to_s)
  $config["preferences"]["name"] = get_name($dbot, $serverID, $dbot.profile.id)
  Thread.new{
    last = ' '
    $fkey
    loop do
      message = ""
      finished = false
      while !finished do
        character = $sp.getc
        if character
          if last.ord.to_i == 1
            if character.ord == 13
              last = ' '
            else
              $fkey = (character.ord.to_i - 63).to_s
              $disable_incomming = true
              handle_fn($dbot, $sp, $config, $fkey)
              $disable_incomming = false
              refresh($sp, $dbot, $db, $config["preferences"]["channel"].to_s, $config["discord"]["server_id"].to_s)
            end
          else
            case character.ord
              # TODO: handle cursor movements
              when 1
                # Fn key
                last = character
              when 13
                # Return
                finished = true
              when 8
                # Backspace
                l = message.size - 2
                message = message[0..l]
                $sp.write("\ez(\r\ez(#{message}\r\ez#{127.chr}")
              else
                message = "#{message}#{character}"
                $sp.write("\ez(\r\ez(#{message}\r\ez#{127.chr}")
            end
          end
        end
      end
      puts message
      if message.size > 0 && message
        # TODO: convert emojis into Discord and Unicode accordingly
        message = Rumoji.decode(message)
        $dbot.channel($config["preferences"]["channel"].to_i).send_message(message)
        # save and display message
        # time example:  2020-04-13 02:17:16 +0000
        time = Time.now.getutc.to_s
        time = time.gsub(" UTC", " +0000")
        push_message($db, message, $dbot.profile.id.to_s, $config["preferences"]["channel"].to_s, time)
        print_message($sp, message, "TERMINAL")
      end
    end
  }
end

$dbot.message() do |event|
  if event.server.id == $config["discord"]["server_id"].to_i
    message = fix_text(event.message.content.to_s)
    time = event.message.timestamp.to_s
    push_message($db, message, event.author.id.to_s, event.channel.id.to_s, time)
    if (event.channel.id.to_s == $config["preferences"]["channel"].to_s && !$disable_incomming)
      # New message is on currently displayed channel
      print_message($sp, message, get_name($dbot, $config["discord"]["server_id"].to_s, event.author.id.to_s))
    end
  end
end

puts "Starting bot..."
$dbot.run