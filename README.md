### Exchange Trade Quote

   自主管理交易所币种 Binance Bittrex

### 执行后台任务 同步行情

    bundle exec rake daemon:quarter_quote:start RAILS_ENV=production

### 配置参数

  完善 config/settings.rb.example 相应的信息，变更为 config/settings.rb


### 定时任务

  */5 * * * * curl http://example.com/api/tickers/fetch &>/dev/null

  0 * * * * curl http://example.com/api/tickers/daemon_launch &>/dev/null
