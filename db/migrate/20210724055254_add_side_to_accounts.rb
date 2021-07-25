class AddSideToAccounts < ActiveRecord::Migration
  def change
    add_column :accounts, :side, :string, default: ''
    add_column :accounts, :total, :float
  end
end
