class CreateRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :relationships do |t|
      t.references :from_person, null: false, foreign_key: { to_table: :people }
      t.references :to_person, null: false, foreign_key: { to_table: :people }
      t.string :kind, null: false

      t.timestamps
    end

    add_index :relationships, %i[from_person_id to_person_id kind], unique: true
  end
end
