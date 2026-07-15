# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_15_014724) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "notes", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_notes_on_person_id"
  end

  create_table "people", force: :cascade do |t|
    t.date "birth_date"
    t.integer "birth_order"
    t.datetime "created_at", null: false
    t.date "death_date"
    t.string "gender", default: "unknown", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_person_id", null: false
    t.string "kind", null: false
    t.bigint "to_person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_person_id", "to_person_id", "kind"], name: "idx_on_from_person_id_to_person_id_kind_ad287fe730", unique: true
    t.index ["from_person_id"], name: "index_relationships_on_from_person_id"
    t.index ["to_person_id"], name: "index_relationships_on_to_person_id"
  end

  add_foreign_key "notes", "people"
  add_foreign_key "relationships", "people", column: "from_person_id"
  add_foreign_key "relationships", "people", column: "to_person_id"
end
