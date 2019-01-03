class AddPrecisionToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :precision, :integer
    add_column :orders,    :cause,     :string
  end
end
