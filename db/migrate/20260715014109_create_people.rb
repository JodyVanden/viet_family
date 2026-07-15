class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :name, null: false
      t.string :gender, null: false, default: "unknown"
      t.date :birth_date
      t.date :death_date
      t.integer :birth_order

      t.timestamps
    end
  end
end
