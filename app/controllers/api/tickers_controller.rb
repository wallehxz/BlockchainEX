class Api::TickersController < ApplicationController

  def fetch
    Market.seq.each do |item|
      item.generate_quote rescue nil
      item.extreme_report rescue nil
    end
    render json: { message: 'sync success'}
  end
end
