# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
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

# every '0,30 * * * *' do
#   runner "Fluctuation.start"
# end

# 止盈止损
every '* * * * *' do
  runner "Stoploss.start"
  runner "Takeprofit.start"
  runner "Chasedown.start"
end

#同步行情数据
every '*/5 * * * *' do
  runner "Ticker.start"
end