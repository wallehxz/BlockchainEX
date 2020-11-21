class AddChaseDownToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :chasedown, :boolean, default: false
  end
end
