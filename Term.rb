require 'serialport'
require 'rumoji'
require 'discordrb'

def clear(port)
    port.write("\e*\e{")
end

# Fix a string to sidplay correctly on the terminal
def fix_text(input)
    # Fix Unicode emojis
    output = Rumoji.encode(input)
    # Fix Discord emojis
    output = output.gsub(/<[a]{,1}(:[a-zA-Z0-9]{1,32}:)[0-9]{18}>/, "\\1")
    # Apply highlighting to all emojis
    output = output.gsub(/(:[a-zA-Z0-9]{1,32}:)/, "\eGt\\1\eG0")
    # Remove any leftover Unicode
    output = output.gsub(/[^[:ascii:]]/, ["02"].pack('H*'))
    # Add carriage returns to newlines
    output = output.gsub("\n", "\n\r")
    # Return fixed string
    output
end

def get_name(bot, server, id)
    member = bot.server(server).member(id)
    name = ""
    if member.nick.to_s.size < 2
        name = member.username
    else
        name = member.nick
    end
    name
end

def get_channel(bot, id)
    name = bot.channel(id).name
    name
end

def setup_database(dbName)
    db = SQLite3::Database.new dbName
    db.execute <<-SQL
    create table messages(
        id int PRIMARY KEY,
        string text,
        author_id text,
        channel_id text,
        posttime text
    );
    SQL
    db
end

def pull_message_sql(count, channel)
    "SELECT string, author_id, posttime FROM messages WHERE channel_id='#{channel}' ORDER BY posttime ASC LIMIT #{count}"
end

def push_message(db, msg, author, channel, time)
    db.execute("INSERT INTO messages (string, author_id, channel_id, posttime) VALUES (?, ?, ?, ?)", [msg, author, channel, time])
end

def push_raw_message(db, msg, author, channel, time)
    msg = fix_text(msg)
    push_message(db, msg, author, channel, time)
end

def print_message(port, msg, author_str)
    port.write("\eG<#{author_str}\eG0 #{msg}\n\r")
end

def refresh(port, bot, db, channel_id, server_id)
    # Set Status Line message
    port.write("\eFChannel: ##{bot.channel(channel_id).name.to_s}\r")
    port.write("\ez(\r\ez#{127.chr}")
    clear(port)
    port.write("\e`0")
    db.execute(pull_message_sql(12, channel_id)) do |row|
        print_message(port, row[0], bot.server(server_id).member(row[1]).nick)
    end
end

def get_serial_message(port, echo_back = false)
    message = ""
    finished = false
    while !finished do
        character = port.getc
        if character
            case character.ord
                when 13
                    # Return
                    finished = true
                when 8
                    # Backspace
                    l = message.size - 2
                    message = message[0..l]
                else
                    message = "#{message}#{character}"
            end
            if echo_back
                # print character
                puts message
            end
            port.write("\ez(\r\ez(#{message}\r\ez#{127.chr}")
        end
    end
    message
end

def wait_space(port)
    waiting = true
    while waiting do
        c = port.getc
        if c
            if c.ord == 32
                waiting = false
            end
        end
    end
end

def handle_fn(bot, port, cfg, fn)
    # Handle Fn keys as functions
    channelHolder = cfg["preferences"]["channel"]
    cfg["preferences"]["channel"] = 0
    case fn.to_i
        when 1
            # Help
            puts "Help Screen"
            port.write("\eFHelp   press the spacebar to exit\r")
            help = File.read('helpScreen.text')
            help = help.gsub("@@", "\eG0")
            help = help.gsub("++", "\eG8")
            help = help.gsub("D+", "\eGt")
            help = help.gsub("==", "\eGp")
            help = help.gsub("\n", "\n\r")
            help.each_line do |line|
                port.write(line)
                sleep 0.01
            end
            wait_space(port)
        when 2
            # Channel Switcher
            puts "Channel Switcher"
        when 3
        when 4

        when 5
        when 6
        when 7
        when 8

        when 9
        when 10
        when 11
        when 12

        when 13
            sleep 2
            # Set nickname (5 lines)
            clear(port)
            for i in 1..cfg["terminal"]["height"].to_i-5
                port.write("\n")
            end
            current_name = cfg["preferences"]["name"]
            port.write("\eG4SET NICKNAME\eG0\n\n\rCurrent:\n\r\eG8#{current_name}\eG0\n\rNew:")
            setting = true
            new_name = ""
            first = true
            while setting do
                print "l"
                c = port.getc
                if c && !first
                    print "C#{c}"
                    case c.ord
                    when 13
                        # Return, set
                        puts "New Name: #{new_name}"
                        cfg["preferences"]["name"] = new_name
                        server = bot.server(cfg["discord"]["server_id"].to_i)
                        member = server.member(bot.profile.id)
                        member.set_nick(new_name)
                        setting = false
                    when 8
                        # Backspace
                        puts "Backspace"
                        l = new_name.size - 2
                        new_name = new_name[0..l]
                        port.write("\ez(\r\ez(#{new_name}\r\ez#{127.chr}")
                    when 32..126
                        print "#{c}"
                        new_name = "#{new_name}#{c}"
                        port.write("\ez(\r\ez(#{new_name}\r\ez#{127.chr}")
                    else
                        puts "OTHER: #{c.ord}"
                    end
                end
                if first
                    first = false
                end
            end
        when 14
        when 15
        when 16
        else
    end
    cfg["preferences"]["channel"] = channelHolder
end