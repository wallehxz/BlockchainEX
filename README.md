### Exchange Trade Quote

   本项目功能基于币安交易所的行情接口，支持自定义现货市场交易对，期货市场交易对，

   自动同步行情，默认为 5 分钟同步一次

   添加自主交易的逻辑，收益不稳定，个人对交易理解开发，风险自负。

   根据不同的指标进行判断交易，指标来源于 TradingView，通知接口

   可参考 https://www.tradingview.com/

### 执行后台任务 同步行情

    bundle exec rake daemon:quarter_quote:start RAILS_ENV=production

### 配置参数

  修改配置文件 config/settings.yml.example

  更名为      config/settings.yml

### 定时任务

    bundle exec whenever --update-crontab
