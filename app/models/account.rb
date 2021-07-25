# == Schema Information
#
# Table name: accounts
#
#  id         :integer          not null, primary key
#  exchange   :string
#  currency   :string
#  balance    :float
#  freezing   :float
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  side       :string           default("")
#  total      :float
#

require 'openssl'
class Account < ActiveRecord::Base
  self.per_page = 10

  # Account.future_balances
  def self.future_balances
    balance_url = 'https://fapi.binance.com/fapi/v2/account'
    timestamp = (Time.now.to_f * 1000).to_i
    params_stirng = "recvWindow=10000&timestamp=#{timestamp}"
    res = Faraday.get do |req|
      req.url balance_url
      req.headers['X-MBX-APIKEY'] = Settings.future_key
      req.params['recvWindow']    = 10000
      req.params['timestamp']     = timestamp
      req.params['signature']     = Account.future_signed(params_stirng)
    end
    JSON.parse(res.body)
  end

  # Account.future_signed
  def self.future_signed(data)
    secret = Settings.future_secret
    digest = OpenSSL::Digest.new('sha256')
    return OpenSSL::HMAC.hexdigest(digest, secret, data)
  end

  # Account.binance_balances
  def self.binance_balances
    balance_url = 'https://api.binance.com/api/v3/account'
    timestamp = (Time.now.to_f * 1000).to_i
    params_stirng = "recvWindow=10000&timestamp=#{timestamp}"
    res = Faraday.get do |req|
      req.url balance_url
      req.headers['X-MBX-APIKEY'] = Settings.binance_key
      req.params['recvWindow']    = 10000
      req.params['timestamp']     = timestamp
      req.params['signature']     = Account.binance_signed(params_stirng)
    end
    JSON.parse(res.body)['balances']
  end

  # Account.binance_signed
  def self.binance_signed(data)
    secret = Settings.binance_secret
    digest = OpenSSL::Digest.new('sha256')
    return OpenSSL::HMAC.hexdigest(digest, secret, data)
  end

  # Account.binance_sync('USDT')
  def self.binance_sync(currency)
    binance_balances.each do |item|
      return item if item['asset'] == currency.upcase
    end
  end

  def side_cn
    {'SHORT' => '做空', 'LONG' => '做多'}[side]
  end

end
