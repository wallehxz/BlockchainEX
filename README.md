### Exchange Trade Quote

   自主管理交易所币种 Binance

### 执行后台任务 同步行情

    bundle exec rake daemon:quarter_quote:start RAILS_ENV=production

### 配置参数

  修改配置文件 config/settings.yml.example
  更名为      config/settings.yml

### 定时任务

    bundle exec whenever --update-crontab
