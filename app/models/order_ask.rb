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
#

class OrderAsk < Order

  def push_order
    if state.init?
      result = market.sync_remote_order(:ask, amount, price)
      self.update_attributes(state: result['state'])
      self.update_attributes(cause: result['cause']) if result['cause']
    end
  end
end
