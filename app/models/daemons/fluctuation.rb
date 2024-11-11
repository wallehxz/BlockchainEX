class Fluctuation
  extend ActiveSupport::NumberHelper
  class << self
    def binance_usdt_tickers
      tip = "【USDT现货行情】\n#{Time.now.to_s(:short)}\n"
      ticker_url = 'https://api.binance.com/api/v3/ticker/24hr'
      res = Faraday.get do |req|
        req.url ticker_url
      end
      markets = JSON.parse(res.body)
      usdt_marts = []
      markets.each do |quote|
        usdt_quot = (quote['symbol'] =~ /USDT/) || 0
        if usdt_quot > 2
          usdt_marts << quote
        end
      end
      usdt_marts = usdt_marts.select {|x| !x['symbol'].include?('UPUSDT')}
      usdt_marts = usdt_marts.select {|x| !x['symbol'].include?('DOWNUSDT')}
      tickers = usdt_marts.sort {|x, y| y['priceChangePercent'].to_f <=> x['priceChangePercent'].to_f }
      (tickers[0..0] + tickers[-1..-1]).each do |quote|
        tip << "#{quote['symbol']} ↑↓ #{quote['priceChangePercent']}, $ #{quote['lastPrice'].to_f}\n"
      end
      Notice.dingding(tip)
    end

    # Fluctuation.future_usdt_tickers
    def future_usdt_tickers
      tip = "【USDT合约行情】\n#{Time.now.to_s(:short)}\n"
      ticker_url = 'https://fapi.binance.com/fapi/v1/ticker/24hr'
      res = Faraday.get do |req|
        req.url ticker_url
      end
      markets = JSON.parse(res.body)
      usdt_marts = []
      markets.each do |quote|
        usdt_quot = (quote['symbol'] =~ /USDT/) || 0
        if usdt_quot > 2
          usdt_marts << quote
        end
      end
      tickers = usdt_marts.sort {|x, y| y['priceChangePercent'].to_f <=> x['priceChangePercent'].to_f }
      (tickers[0..1] + tickers[-2..-1]).each do |quote|
        tip << "#{quote['symbol']} ↑↓ #{quote['priceChangePercent']} ,$ #{quote['lastPrice'].to_f} \n"
      end
      Notice.dingding(tip)
    end

    def start
      begin
        future_usdt_tickers if Setting.fluctuation_future
        binance_usdt_tickers if Setting.fluctuation_binance
      rescue => detail
        Notice.exception(detail, "Deamon Fluctuation")
      end
    end

    # Fluctuation.binance_usdt_volume
    def binance_usdt_volume
      ticker_url = 'https://api.binance.com/api/v3/ticker/24hr'
      res = Faraday.get do |req|
        req.url ticker_url
      end
      markets = JSON.parse(res.body)
      usdt_rise = []
      markets.each do |quote|
        usdt_quot = (quote['symbol'] =~ /USDT/) || 0
        usdt_rise << quote if usdt_quot > 2 && quote['priceChangePercent'].to_f > 0
      end
      usdt_rise = usdt_rise.select {|x| !x['symbol'].include?('UPUSDT')}
      usdt_rise = usdt_rise.select {|x| !x['symbol'].include?('DOWNUSDT')}
      rise_list = usdt_rise.sort {|x, y| y['priceChangePercent'].to_f <=> x['priceChangePercent'].to_f }
      rise_list.map { |m| market_hour_ticker(m['symbol']) }
    end

    def market_hour_ticker(symbol, amount = 24)
      puts "Processing #{symbol} ..."
      market_url = 'https://api.binance.com/api/v3/klines'
      res = Faraday.get do |req|
        req.url market_url
        req.params['symbol'] = symbol
        req.params['interval'] = '1h'
        req.params['limit'] = amount
      end
      klines = JSON.parse(res.body)
      return false unless (Time.at klines[-1][0]/1000).to_date.today?
      avg_5h_volumes = klines[-6..-2].map { |k| k[5].to_f }.sum / 5
      day_vols = klines.map { |k| k[5].to_f }.sum
      cur_volumes = klines[-1][5].to_f
      day_usdt_vols = klines.map { |k| k[7].to_f }.sum
      if cur_volumes >= avg_5h_volumes * 5
        volume_tip(symbol, avg_5h_volumes, cur_volumes, day_vols, day_usdt_vols)
      end
    end

    def volume_tip(symbol, ave_vol, cur_vol, day_vol, day_usdt_vol)
      tip = "#{symbol} 成交量 爆量通知\n"
      tip << "当前小时交易量是前5个小时平均交易量的 #{(cur_vol/ave_vol).to_i}x\n"
      tip << "前五小时平均交易量 #{million_unit(ave_vol)} \n"
      tip << "当前小时交易量 #{million_unit(cur_vol)} \n"
      tip << "目前日交易量 #{million_unit(day_vol)} \n"
      tip << "目前 USDT 日交易量 #{million_unit(day_usdt_vol)}"
      Notice.volume(tip)
    end

    # Fluctuation.million_unit(143169)
    def million_unit(num)
      human_size = num / 1000000.0
      if human_size > 0.01
        return "#{human_size.round(2)} M"
      elsif human_size.between?(0.001,0.01)
        return "#{human_size.round(3)} M"
      elsif human_size.between?(0.0001,0.001)
        return "#{human_size.round(4)} M"
      elsif human_size.between?(0.00001,0.0001)
        return "#{human_size.round(5)} M"
      else
        return "#{human_size.round(6)} M"
      end
    end

  end
end