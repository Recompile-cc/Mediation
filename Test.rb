$LOAD_PATH.unshift(File.expand_path('../', __FILE__))

# require 'serialport'
# require 'Term.rb'
require 'discordrb'
require 'json'

$config = JSON.parse(File.read('config.json'))
# $sp = SerialPort.new("/dev/ttyUSB0")
# $sp.baud = 115200
# $sp.data_bits = 8
# $sp.stop_bits = 1
# $sp.parity = SerialPort::NONE
# $sp.flow_control = SerialPort::NONE
# $sp.read_timeout = 50
$dbot = Discordrb::Bot.new token: $config["discord"]["bot_token"]

$dbot.ready do |e|
    puts "Connected."
    server = $dbot.server($config["discord"]["server_id"].to_i)
    member = server.member($dbot.profile.id)
    if member.nick.to_s.size < 2
        puts member.username
    else
        puts member.nick
    end
    $dbot.stop
end

$dbot.run