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
    name = bot.server(server).member(id).nick
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
    "SELECT string, author_id, posttime FROM messages WHERE channel_id='#{channel}' ORDER BY posttime DESC LIMIT #{count}"
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
    clear(port)
    db.execute(pull_message_sql(12, channel_id)) do |row|
        print_message(port, row[0], bot.server(server_id).member(row[1]).nick)
    end
end