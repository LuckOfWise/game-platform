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

ActiveRecord::Schema[8.1].define(version: 2026_02_24_032113) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "game_participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", null: false
    t.bigint "game_session_id", null: false
    t.integer "slot", null: false
    t.datetime "updated_at", null: false
    t.index ["game_session_id", "slot"], name: "index_game_participants_on_game_session_id_and_slot", unique: true
    t.index ["game_session_id"], name: "index_game_participants_on_game_session_id"
  end

  create_table "game_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_player_slot"
    t.string "game_key", null: false
    t.string "seed", null: false
    t.jsonb "state", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 0, null: false
    t.integer "winner_slot"
    t.index ["game_key"], name: "index_game_sessions_on_game_key"
  end

  add_foreign_key "game_participants", "game_sessions"
end
