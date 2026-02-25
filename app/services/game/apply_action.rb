# frozen_string_literal: true

module Game
  class ApplyAction
    class Error < StandardError; end
    class VersionMismatch < Error; end

    def self.call(session_id:, actor_slot:, action:, client_version:)
      payload = nil

      GameSession.transaction do
        session = GameSession.lock.find(session_id)

        raise VersionMismatch, "version mismatch" if session.version != client_version.to_i

        engine_klass = Games::Registry.fetch(session.game_key)
        engine = engine_klass.new(seed: session.seed)

        new_state = engine.apply_action(state: session.state, action: action, actor_slot: actor_slot)

        session.state = new_state
        session.status =
          case new_state["phase"]
          when "waiting_for_players", "dice_roll" then :waiting
          when "play" then :playing
          when "finished" then :finished
          else :playing
          end
        session.current_player_slot = new_state["turn"]
        session.winner_slot = new_state["winner_slot"]
        session.version += 1
        session.save!

        payload = {
          type: "state",
          session_id: session.id,
          version: session.version,
          status: session.status,
          current_player_slot: session.current_player_slot,
          winner_slot: session.winner_slot,
          state: new_state
        }
      end

      ActionCable.server.broadcast("game_session:#{payload[:session_id]}", payload)

      payload
    end
  end
end
