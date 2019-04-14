class AddCategoryToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :category, :string, default: 'limit'
    add_column :regulates, :fast_cash, :float
  end
end
