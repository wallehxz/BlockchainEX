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

def highest?
  $c_market.max_24 == $c_market.last_quote.c
end

def lowest?
  $c_market.min_24 == $c_market.last_quote.c
end

def low_to_up
  if $c_market.tip? && lowest?
    $c_market.get_price[:last] > $c_market.last_quote.c
    tip = "#{$c_market.full_name} 回升，#{$c_market.last_quote.c} => #{$c_market.get_price[:last]}"
    $c_market.quote_notice tip
    puts "[ #{Time.now.httpdate} ] #{tip}"
  end
end

def up_to_low
  if $c_market.tip? && highest?
    $c_market.get_price[:last] < $c_market.last_quote.c
    tip = "#{$c_market.full_name} 回落，#{$c_market.last_quote.c} => #{$c_market.get_price[:last]}"
    $c_market.quote_notice tip
    puts "[ #{Time.now.httpdate} ] #{tip}"
  end
end

while $running
  starting = Time.now
  Market.seq.each do |item|
    $c_market = item
    low_to_up
    up_to_low
  end rescue nil
  consume = Time.now - starting
  offset_second = Time.now.strftime("%S").to_i + 3 - consume
  sleep (300 - offset_second)
end
