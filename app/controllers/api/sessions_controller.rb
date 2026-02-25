module Api
  class SessionsController < ApplicationController
    def show
      session = GameSession.preload(:game_participants).find(params[:id])
      slot = cookies.signed["bj_slot_#{session.id}"]&.to_i
      render json: {
        session_id: session.id,
        slot: slot,
        state: session.state,
        version: session.version,
        players_count: session.game_participants.size
      }
    end
  end
end
