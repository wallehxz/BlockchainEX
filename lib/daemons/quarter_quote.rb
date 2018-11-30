#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "development"

root = File.expand_path(__dir__)
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

while $running
  start_at = Time.now
  Market.seq.each do |item|
    item.generate_quote rescue nil
  end
  consume = Time.now - start_at
  sleep (900 - consume)
end
