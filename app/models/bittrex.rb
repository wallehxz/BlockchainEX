# == Schema Information
#
# Table name: markets
#
#  id         :integer          not null, primary key
#  base_unit  :string
#  quote_unit :string
#  sequence   :integer
#  source     :string
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Bittrex < Market

  def get_price
    t = get_ticker
    { last: t['Last'], ask: t['Ask'], bid: t['Bid'] }
  end

  def symbol
    "#{base_unit}-#{quote_unit}"
  end

  def get_ticker
    ticker_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def get_market
    market_url = 'https://bittrex.com/api/v1.1/public/getmarketsummary'
    res = Faraday.get do |req|
      req.url market_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    current['result'][0]
  end

  def get_market_history
    history_url = 'https://bittrex.com/api/v1.1/public/getmarkethistory'
    res = Faraday.get do |req|
      req.url history_url
      req.params['market'] = "#{base_unit}-#{quote_unit}"
    end
    current = JSON.parse(res.body)
    binding.pry
    current['result']
  end

  def generate_quote
    t = get_ticker
    ticker = {}
    ticker[:o] = last_quote&.c || t['Last']
    ticker[:h] = t['Last'] * 1.005
    ticker[:l] = t['Last'] * 0.995
    ticker[:c] = t['Last']
    ticker[:v] = (rand * 50).to_d.round(4)
    ticker[:t] = Time.now.to_i
    ticker
    candles.create(ticker)
  end

  def sync_fund
    remote =Account.bittrex_sync(quote_unit)
    locale = fund || build_fund
    locale.balance = remote['Balance'].to_f
    locale.freezing = remote['Pending'].to_f
    locale.save
  end

  def sync_cash
    remote = Account.bittrex_sync(base_unit)
    locale = cash || build_cash
    locale.balance = remote['Balance'].to_f
    locale.freezing = remote['Pending'].to_f
    locale.save
  end

  def sync_remote_order(side, amount, price)
    begin
      order_url = { 'bid': 'https://bittrex.com/api/v1.1/market/buylimit', 'ask': 'https://bittrex.com/api/v1.1/market/selllimit' }[side]
      timetamp = Time.now.to_i
      sign_url = "#{order_url}?#{sign_query(timetamp, amount, price)}"
      res = Faraday.get do |req|
        req.url order_url
        req.headers['apisign'] = Account.bittrex_hamc_digest(sign_url)
        req.params['apikey'] = Settings.bittrex_key
        req.params['market'] = symbol
        req.params['nonce'] = timetamp
        req.params['quantity'] = amount
        req.params['rate'] = price
      end
      result = JSON.parse(res.body)
      result['success'] ? { 'state'=> 200 } : { 'state'=> 500, 'cause'=> result['message'] }
    rescue Exception => detail
      { 'state'=> 500, 'cause'=> detail.cause }
    end
  end

  def sign_query(timetamp, amount, price)
    query_arry = ["apikey=#{Settings.bittrex_key}","market=#{symbol}","nonce=#{timetamp}","quantity=#{amount}","rate=#{price}"]
    query_arry.sort.join('&')
  end
end
