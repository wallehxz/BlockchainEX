#!/usr/bin/env ruby

# You might want to change this [development,production]
#bundle exec rake daemon:quarter_quote:start RAILS_ENV=production
ENV["RAILS_ENV"] ||= 'production'

root = File.expand_path(__dir__)
root = File.dirname(root) until File.exist?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true

Signal.trap("TERM") do
  $running = false
end

while $running
  begin
    starting = Time.now
    Market.seq.each do |item|
      item.generate_quote rescue nil
      item.extreme_report rescue nil
    end
    consume = Time.now - starting
    sleep (900 - consume)
  rescue => detail
    print detail.backtrace.join("\n")
    sleep 900
  end
end
