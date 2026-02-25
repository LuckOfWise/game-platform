class GameSession < ApplicationRecord
  has_many :game_participants, dependent: :destroy

  enum :status, { waiting: 0, playing: 1, finished: 2 }

  validates :game_key, presence: true
  validates :seed, presence: true

  def players_count
    game_participants.size
  end
end
