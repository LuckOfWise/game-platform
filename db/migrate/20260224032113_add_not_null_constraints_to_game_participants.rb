class AddNotNullConstraintsToGameParticipants < ActiveRecord::Migration[8.1]
  def change
    change_column_null :game_participants, :slot, false
    change_column_null :game_participants, :display_name, false
  end
end
