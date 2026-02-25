import consumer from "./consumer"

export function subscribeGameSession(sessionId, handlers) {
  return consumer.subscriptions.create(
    { channel: "GameSessionChannel", session_id: sessionId },
    {
      received(data) { handlers?.onReceive?.(data) },
      action(payload) { this.perform("action", payload) }
    }
  )
}
