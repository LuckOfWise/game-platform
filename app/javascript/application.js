import "@hotwired/turbo-rails"
import "./controllers"
import { subscribeGameSession } from "./channels/game_session_channel"

let currentSub = null

document.addEventListener("turbo:load", () => {
  if (currentSub) {
    currentSub.unsubscribe()
    currentSub = null
  }

  const el = document.getElementById("app")
  if (el) boot(el)
})

async function boot(root) {
  const sessionId = root.dataset.sessionId

  const res = await fetch(`/api/sessions/${sessionId}`)
  const initial = await res.json()

  let state = initial.state
  let version = initial.version
  const slot = initial.slot
  let selected = null
  let selectedDie = 1

  const sub = subscribeGameSession(sessionId, {
    onReceive(data) {
      if (data.type === "state") {
        version = data.version
        state = data.state
        render()
      } else if (data.type === "error") {
        alert(data.message)
      }
    }
  })
  currentSub = sub

  function send(action) {
    if (!slot) return alert("先に参加してね")
    sub.action({
      client_version: version,
      action
    })
  }

  function isCenter(r,c) {
    return (r===1 || r===2) && (c===1 || c===2)
  }

  function cellHtml(cell) {
    if (!cell) return `<div class="small"> </div>`
    const owner = cell.owner
    const top = cell.faces.top
    const cls = owner === 1 ? "p1" : "p2"
    return `<div class="piece ${cls}">${top}</div>`
  }

  function scores() {
    const board = state.board
    let s1=0,s2=0
    for (let r=0;r<4;r++) for (let c=0;c<4;c++) {
      const cell = board[r][c]
      if (!cell) continue
      if (cell.owner===1) s1 += cell.faces.top
      if (cell.owner===2) s2 += cell.faces.top
    }
    return [s1,s2]
  }

  function phaseLabel(phase) {
    const labels = {
      "waiting_for_players": "対戦相手を待っています",
      "dice_roll": "先攻決定（ダイスロール）",
      "placement": "初期配置",
      "play": "対戦中",
      "finished": "終了"
    }
    return labels[phase] || phase
  }

  function render() {
    if (!state) return
    const [s1,s2] = scores()
    const phase = state.phase
    const turn = state.turn
    const winner = state.winner

    const myTurn = slot && turn === slot
    const canPlay = slot && (phase === "dice_roll" || phase === "placement" || phase === "play")

    root.innerHTML = `
      <div class="game">
        <div class="panel">
          <div class="kv"><div class="small">あなた</div><div>${slot ? `Player ${slot}` : `未参加`}</div></div>
          <div class="kv"><div class="small">フェーズ</div><div><span class="badge">${phaseLabel(phase)}</span></div></div>
          ${turn ? `
            <div class="kv"><div class="small">手番</div><div>
              <span class="badge ${turn===1 ? "p1": "p2"}">Player ${turn}</span>
              ${slot ? (myTurn ? "（あなた）" : "") : ""}
            </div></div>
          ` : ""}
          ${phase === "placement" || phase === "play" || phase === "finished" ? `
            <div class="kv"><div class="small">スコア</div><div>
              <span class="badge p1">P1: ${s1}</span>
              <span class="badge p2">P2: ${s2}</span>
            </div></div>
          ` : ""}

          ${winner ? `<div class="kv"><div class="small">勝者</div><div><strong>Player ${winner}</strong></div></div>` : ""}

          <hr style="border:0;border-top:1px solid var(--border);margin:12px 0;" />

          ${slot ? controlsHtml(phase, canPlay, myTurn) : `<div class="small">参加すると操作できます</div>`}
        </div>

        <div class="panel">
          <div class="small">盤面（クリックで選択）</div>
          <div class="board">
            ${state.board.map((row,r) => row.map((cell,c) => `
              <div class="cell ${isCenter(r,c) ? "center":""} ${(selected && selected[0]===r && selected[1]===c) ? "selected":""}" data-r="${r}" data-c="${c}">
                ${cellHtml(cell)}
              </div>
            `).join("")).join("")}
          </div>
          <div class="small" style="margin-top:10px;">
            ルール要点：中央4マスに初期配置、上下左右に1マス移動、最大2個まで押し転がし、11ぴったりで勝ち・相手が12以上になったら勝ち
          </div>
        </div>
      </div>
    `

    root.querySelectorAll(".cell").forEach((node) => {
      node.addEventListener("click", () => {
        const r = parseInt(node.dataset.r,10)
        const c = parseInt(node.dataset.c,10)
        selected = [r,c]
        render()
      })
    })

    root.querySelectorAll("[data-dir]").forEach((btn) => {
      btn.addEventListener("click", () => {
        if (!selected) return alert("まず自分のコマを選択")
        send({ type: "move", from: selected, dir: btn.dataset.dir })
      })
    })

    const placeBtn = root.querySelector("[data-place]")
    if (placeBtn) {
      placeBtn.addEventListener("click", () => {
        if (!selected) return alert("中央4マスの空きをクリックして選択")
        send({ type: "place", die_index: selectedDie, pos: selected })
      })
    }

    const dieSelect = root.querySelector("[data-die]")
    if (dieSelect) {
      selectedDie = parseInt(dieSelect.value, 10)
      dieSelect.addEventListener("change", (e) => {
        selectedDie = parseInt(e.target.value,10)
      })
    }

    const rollBtn = root.querySelector("[data-roll-dice]")
    if (rollBtn) {
      rollBtn.addEventListener("click", () => {
        send({ type: "roll_dice" })
      })
    }
  }

  function controlsHtml(phase, canPlay, myTurn) {
    if (phase === "waiting_for_players") {
      return `<div class="small">対戦相手の参加を待っています...</div>`
    }

    if (phase === "dice_roll") {
      const myRoll = state.dice_roll?.[String(slot)]
      const isTie = state.dice_roll?.result === "tie"

      if (myRoll && !isTie) {
        return `
          <div class="small">あなたのダイス: [${myRoll.dice.join(", ")}] 合計: ${myRoll.sum}</div>
          <div class="small">相手のロールを待っています...</div>
        `
      }

      let html = ""
      if (isTie) {
        html += `<div class="small" style="color: #f59e0b;">引き分けです。もう一度振ってください。</div>`
      }
      html += `
        <div class="small">先攻を決めるため、ダイスを3つ振ります。</div>
        <div class="controls">
          <button class="btn" data-roll-dice>ダイスを振る</button>
        </div>
      `
      return html
    }

    if (!canPlay) return `<div class="small">操作不可</div>`
    if (!myTurn) return `<div class="small">相手の手番です</div>`

    if (phase === "placement") {
      const placed = state.placed?.[String(slot)] || []
      const availableDice = [1, 2, 3].filter(i => !placed.includes(i))
      const dieOptions = availableDice.map(i => `<option value="${i}">die ${i}</option>`).join("")

      return `
        <div class="small">初期配置：中央4マスに、自分のダイスを3つ置く</div>
        <div class="controls">
          <select data-die class="dirbtn">
            ${dieOptions}
          </select>
          <button class="btn" data-place>選択マスに置く</button>
        </div>
      `
    }

    if (phase === "play") {
      return `
        <div class="small">移動：自分のコマを選択して方向ボタン</div>
        <div class="controls">
          <button class="dirbtn" data-dir="N">↑</button>
          <button class="dirbtn" data-dir="W">←</button>
          <button class="dirbtn" data-dir="S">↓</button>
          <button class="dirbtn" data-dir="E">→</button>
        </div>
      `
    }

    return `<div class="small">終了</div>`
  }

  render()
}
