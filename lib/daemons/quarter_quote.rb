#!/usr/bin/env ruby

# You might want to change this [development,production]
ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(__dir__)
root = File.dirname(root) until File.exist?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

while $running
  starting = Time.now
  Market.seq.each do |item|
    item.generate_quote rescue nil
  end
  consume = Time.now - starting
  offset_second = Time.now.strftime("%S").to_i + 3 - consume
  sleep (900 - offset_second)
end
