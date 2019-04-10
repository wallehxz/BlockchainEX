class AddResistanceSupportToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :support, :float
    add_column :regulates, :resistance, :float
  end
end
