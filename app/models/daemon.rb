class Daemon
  class << self

    # ["tradingview", "takeprofit", "stoploss", "fastrade", "fluctuation"]
    def list
      Daemons::Rails::Monitoring.statuses.keys.map {|x| x.chomp('.rb')}
    end

    def start(daemon)
      title = "#{daemon}.rb"
      status = Daemons::Rails::Monitoring.statuses
      unless status[title] == :running
        root_path = Rails.root
        start_daemon ="bundle exec rake daemon:#{daemon}:start"
        shell_cmd = "cd #{root_path} && #{start_daemon}"
        system("#{shell_cmd}")
        Notice.dingding("开启 #{daemon.camelcase} 进程")
      end
    end

    def stop(daemon)
      title = "#{daemon}.rb"
      status = Daemons::Rails::Monitoring.statuses
      if status[title] == :running
        root_path = Rails.root
        start_daemon ="bundle exec rake daemon:#{daemon}:stop"
        shell_cmd = "cd #{root_path} && #{start_daemon}"
        system("#{shell_cmd}")
        Notice.dingding("关闭 #{daemon.camelcase} 进程")
      end
    end

  end
end