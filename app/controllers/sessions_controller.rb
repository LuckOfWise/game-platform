class SessionsController < ApplicationController
  def create
    seed = SecureRandom.hex(16)
    engine = Games::BlockJack::Engine.new(seed: seed)

    state = engine.initial_state
    state = engine.add_player(state: state, slot: 1)

    session = GameSession.create!(
      game_key: "blockjack",
      seed: seed,
      status: :waiting,
      state: state,
      current_player_slot: nil
    )

    session.game_participants.create!(slot: 1, display_name: create_params[:display_name].presence || "Player1")
    cookies.permanent.signed["bj_slot_#{session.id}"] = 1

    redirect_to session_path(session)
  end

  def show
    @session = GameSession.preload(:game_participants).find(params[:id])
  end

  def join
    session_id = params[:id]
    existing_slot = cookies.signed["bj_slot_#{session_id}"]

    if existing_slot.present?
      redirect_to session_path(session_id), alert: "既に参加しています"
      return
    end

    payload = nil

    GameSession.transaction do
      session = GameSession.lock.find(session_id)

      slot = (session.game_participants.maximum(:slot) || 0) + 1
      raise ActionController::BadRequest, "Session is full" if slot > 2

      session.game_participants.create!(slot: slot, display_name: join_params[:display_name].presence || "Player#{slot}")

      engine = Games::Registry.fetch(session.game_key).new(seed: session.seed)
      new_state = engine.add_player(state: session.state, slot: slot)
      session.update!(state: new_state, version: session.version + 1)

      cookies.permanent.signed["bj_slot_#{session.id}"] = slot

      payload = {
        type: "state",
        session_id: session.id,
        version: session.version,
        status: session.status,
        current_player_slot: session.current_player_slot,
        state: new_state
      }
    end

    ActionCable.server.broadcast("game_session:#{payload[:session_id]}", payload)

    redirect_to session_path(params[:id])
  end

  private

  def create_params
    params.permit(:display_name)
  end

  def join_params
    params.permit(:display_name)
  end
end
