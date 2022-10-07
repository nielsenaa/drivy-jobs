#!/usr/bin/env ruby
#coding:utf-8

# LEVEL 4 Notes/short explanation 
#
# "Please include a short explanation (<200 words) that highlights some of the advantages and shortcommings of your approach."
#
# As this is my first time -ever- coding in Ruby, i went the simplest strict minimum, quickest and the most straigth-forward way available to me
# to achieve each level requirements, so i probably overlooked many things (exceptions/errors catching certainly!)
# but i had to, otherwise i would never finish this assignment on time. I am looking forward to a eye-opening code review :) 
#
# Having said that, in my opinion the advantages of this approach are :
# - One unique out of the box standalone file, lowest dependencies possible
# - Short, easy to read process, simple to understand for a Ruby first-timer like me
# - (probably naïve) Easily re-usable, modifiable, adaptable, extendable code
# - Runs anywhere Ruby is installed. nothing more needed
#
# And the shortcomings are :
# - The process_log function is totaly tied to the log format received. Any deviation of the format will probably result in malformed final json
# - Works localy as required (http answers <100ms, 10s process time before response), but will probably not under heavier load. Will miss data, and it will be unrecoverable.  
# - If ever the main loop dies, the script will crash, no more logging at all. I would start this script as a systemd service, so i could rely on it to gracefully restart the script.
#
#


require_relative("slow_computation")
require 'redis'
require 'json'
require 'socket'


def process_log(redis_inst,log_data)

  #post sample
  #{"log":"id=42ac02d9-de9a-4a08-b1f9-88c09c70f011 service_name=admin process=admin.714 sample#load_avg_1m=0.515 sample#load_avg_5m=0.747 sample#load_avg_15m=0.858"}

  log_data = log_data.gsub("\"log\":", "").gsub(" ", "\",\n  \"").gsub("sample#", "").gsub("=", "\": \"").gsub("{", "{\n  ").gsub("}", "\n}")

  new_json = SlowComputation.new(log_data).compute

  redis_inst.rpush('LIST',new_json)

end


#lets go

redis_inst = Redis.new(host: "127.0.0.1", port: 6379, db: 0)

socket = TCPServer.new("127.0.0.1", 3000)

loop do

  begin

    client = socket.accept
    first_line = client.gets
    verb, path, _ = first_line.split

    #restrict answer to post requests only
    if verb == 'POST'

        headers = {}
        while line = client.gets.split(' ', 2)              # Collect HTTP headers
          break if line[0] == ""                            # Blank line means no more headers
          headers[line[0].chop] = line[1].strip             # Hash headers by type
        end
        log_data = client.read(headers["Content-Length"].to_i)  # Read the POST data as specified in the header

        #child process the log
        Thread.new do
          process_log(redis_inst,log_data)
        end

        #unfortunately does not work on WSL1/2 (my ad hoc dev env)
        #child_pid = fork do
        #  process_log(log_data)
        #  exit
        #end

        #http answer to client
        response = "HTTP/1.1 200\r\n\r\n"
        client.puts(response)

    end

    client.close

  rescue
  end

end

socket.close