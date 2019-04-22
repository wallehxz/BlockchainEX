class AddPricePrecisionToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :amount_precision, :integer
    add_column :regulates, :price_precision, :integer
    remove_column :regulates, :precision
  end
end
