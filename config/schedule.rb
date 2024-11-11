# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#

# set :bundle_command, '/root/.asdf/shims/bundle exec'
# set :output, '/root/cron-ruby.log'

#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# every :hour do
#   runner "Exchange.sync_hour_snapshot"
# end

# every 1.day, at: ['8:00 am'] do
#   runner "Exchange.sync_day_snapshot"
# end

# every '* * * * *' do
#   runner "Crawl.catch_dislocation"
# end
# Learn more: http://github.com/javan/whenever

# 获取期货涨跌排行

every '0,30 * * * *' do
  runner "Fluctuation.start"
end

every '15,30,45,59 * * * *' do
  runner "Fluctuation.binance_usdt_volume"
end

# 止盈止损
# every '* * * * *' do
#   runner "Stoploss.start"
#   runner "Takeprofit.start"
#   runner "Chasedown.start"
# end

#同步行情数据
every '*/5 * * * *' do
  runner "Ticker.start"
end

# Learn more: http://github.com/javan/whenever

# bundle exec whenever --update-crontab -s 'environment=development'