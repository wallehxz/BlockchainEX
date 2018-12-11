class CreateAccounts < ActiveRecord::Migration
  def change
    create_table :accounts do |t|
      t.string  :exchange
      t.string  :currency
      t.float   :balance
      t.float   :freezing
      t.timestamps null: false
    end
  end
end
