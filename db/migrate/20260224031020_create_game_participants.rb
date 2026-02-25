class CreateGameParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :game_participants do |t|
      t.references :game_session, null: false, foreign_key: true
      t.integer :slot
      t.string :display_name

      t.timestamps
    end

    add_index :game_participants, [ :game_session_id, :slot ], unique: true
  end
end
