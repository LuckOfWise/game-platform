# frozen_string_literal: true

module Games
  class Registry
    def self.fetch(game_key)
      case game_key
      when "blockjack"
        Games::BlockJack::Engine
      else
        raise "Unknown game_key: #{game_key}"
      end
    end
  end
end
