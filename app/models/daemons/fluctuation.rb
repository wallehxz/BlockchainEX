class Fluctuation
  class << self
    def binance_usdt_tickers
      tip = "【USDT现货行情】\n#{Time.now.to_s(:short)}\n"
      ticker_url = 'https://api.binance.com/api/v1/ticker/24hr'
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
        future_usdt_tickers if Settings.fluctuation_future
        binance_usdt_tickers if Settings.fluctuation_binance
      rescue => detail
        Notice.exception(detail, "Deamon Fluctuation")
      end
    end
  end
end