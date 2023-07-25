class WelcomeController < ApplicationController
  layout 'web'

  def index
    if Market.first
      redirect_to market_quote_path(Market.first.symbols)
    end
  end

  def trends
  end

end
