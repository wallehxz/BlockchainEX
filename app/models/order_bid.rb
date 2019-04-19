# == Schema Information
#
# Table name: orders
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  type       :string
#  price      :float
#  amount     :float
#  total      :float
#  state      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cause      :string
#  category   :string           default("limit")
#

class OrderBid < Order

  def push_order
    if state.init?
      if Rails.env.production?
        result = market.sync_remote_order(:bid, amount, price)
        self.update_attributes(state: result['state'], cause: result['cause'])
      else
        mock_push
      end
    end
  end
end
