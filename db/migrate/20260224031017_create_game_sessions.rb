class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.string :game_key, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :state, null: false, default: {}
      t.integer :version, null: false, default: 0
      t.integer :current_player_slot
      t.string :seed, null: false
      t.integer :winner_slot

      t.timestamps
    end

    add_index :game_sessions, :game_key
  end
end
