# frozen_string_literal: true

class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]
    @actor_slot = cookies.signed["bj_slot_#{@session_id}"]&.to_i
    stream_from "game_session:#{@session_id}"
  end

  def action(data)
    unless @actor_slot
      transmit(type: "error", message: "参加者として登録されていません")
      return
    end

    payload = Game::ApplyAction.call(
      session_id: @session_id,
      actor_slot: @actor_slot,
      action: data["action"],
      client_version: data["client_version"]
    )
    transmit(payload)
  rescue Game::ApplyAction::Error, RuntimeError => e
    transmit(type: "error", message: e.message)
  rescue StandardError => e
    Rails.logger.error("GameSessionChannel unexpected error: #{e.class} - #{e.message}")
    transmit(type: "error", message: "予期しないエラーが発生しました")
  end
end
