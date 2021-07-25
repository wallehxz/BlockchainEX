class AddPositionToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :position, :string
  end
end
