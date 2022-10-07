#!/usr/bin/env ruby
#coding:utf-8

require 'json'

def get_file_content(name)

  #read, process
  file_data = File.read("./logs/#{name}").split.to_json
  file_data = file_data.gsub(",", ",\n  ").gsub("sample#", "").gsub("=", "\": \"").gsub("[", "{\n  ").gsub("]", "\n}")

  return file_data

end


#lets go

if Dir.exist?("./logs/")

  Dir.mkdir("./parsed/") unless File.exists?("./parsed/")

  Dir.entries("./logs/").each do |name|

  	begin

      if File.extname(name) === ".txt"

        file_content = get_file_content(name)

        new_file_name = File.basename(name, ".*")

          if File.write("./parsed/#{new_file_name}.json", file_content)

            File.delete("./logs/#{name}")

          end

      end

    rescue
    end

  end

end