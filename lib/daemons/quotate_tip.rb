#!/usr/bin/env ruby

# You might want to change this [development,production]
# bundle exec rake daemon:quotate_tip:start RAILS_ENV=production
ENV["RAILS_ENV"] ||= 'production'

root = File.expand_path(__dir__)
root = File.dirname(root) until File.exist?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true

Signal.trap("TERM") do
  $running = false
end

def highest?
  $c_market.max_96 == $c_market.last_quote.c
end

def lowest?
  $c_market.min_96 == $c_market.last_quote.c
end

def low_to_up
  if $c_market.tip? && lowest? && $c_market.last_quote.c < $c_market.get_price[:last]
    tip = "#{$c_market.full_name} 下跌回升，#{$c_market.last_quote.c} => #{$c_market.get_price[:last]}"
    $c_market.quote_notice tip
  end
end

def up_to_low
  if $c_market.tip? && highest? && $c_market.last_quote.c > $c_market.get_price[:last]
    tip = "#{$c_market.full_name} 上涨回落，#{$c_market.last_quote.c} => #{$c_market.get_price[:last]}"
    $c_market.quote_notice tip
  end
end

while $running
  begin
    starting = Time.now
    Market.seq.each do |item|
      $c_market = item
      low_to_up rescue nil
      up_to_low rescue nil
    end
    consume = Time.now - starting
    sleep (300 - consume)
  rescue => detail
    print detail.backtrace.join("\n")
    sleep 300
  end
end
