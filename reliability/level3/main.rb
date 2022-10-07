#!/usr/bin/env ruby
#coding:utf-8

require 'redis'
require 'json'
require 'socket'


def process_log(redis_inst,log_data)

  #post sample
  #{"log":"id=42ac02d9-de9a-4a08-b1f9-88c09c70f011 service_name=admin process=admin.714 sample#load_avg_1m=0.515 sample#load_avg_5m=0.747 sample#load_avg_15m=0.858"}

  log_data = log_data.gsub("\"log\":", "").gsub(" ", "\",\n  \"").gsub("sample#", "").gsub("=", "\": \"").gsub("{", "{\n  ").gsub("}", "\n}")
  
  redis_inst.rpush('LIST',log_data)
  
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