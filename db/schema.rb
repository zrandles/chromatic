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

ActiveRecord::Schema[8.1].define(version: 2025_10_13_204234) do
  create_table "color_paths", force: :cascade do |t|
    t.text "cards_data"
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "game_id", null: false
    t.string "player_type"
    t.integer "score"
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_color_paths_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "ai_score"
    t.datetime "created_at", null: false
    t.integer "current_round"
    t.text "game_state"
    t.integer "player_score"
    t.string "status"
    t.integer "total_rounds"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "color_paths", "games"
end
