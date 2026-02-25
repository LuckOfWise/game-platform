class GameParticipant < ApplicationRecord
  belongs_to :game_session

  validates :slot, presence: true
  validates :display_name, presence: true
end
