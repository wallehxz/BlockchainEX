# coding: utf-8
require 'digest'
require 'openssl'

class Dashboard

  def self.hamc_digest(string)
    sha512 = OpenSSL::Digest.new('SHA512')
    OpenSSL::HMAC.hexdigest(sha512, Settings.apiSecret, string)
  end

end