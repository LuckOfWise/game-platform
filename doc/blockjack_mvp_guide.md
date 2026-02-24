# BlockJack Online (Rails + ActionCable) — MVP手順書（`rails new`後から完成まで）

要件：
- Rails（`esbuild`使用）
- CSSは素で書く（Tailwind等なし）
- マッチング不要（URLを共有して2人で遊ぶ）
- URLアクセス → 参加 → リアルタイム対戦（ActionCable）

> ここでは **「動くMVP」** を最短で作る。認証・観戦・Bot・リプレイは後回し。

---

## 0. 前提

- Ruby / Railsインストール済み
- PostgreSQL 起動済み
- Redis 起動済み（ActionCable用）

---

## 1. プロジェクト作成（ハイフン名 / esbuild）

```bash
rails new blockjack-platform -d postgresql --javascript=esbuild
cd blockjack-platform
bin/rails db:create
```

起動確認（この時点ではまだOK）：

```bash
bin/dev
```

---

## 2. Redis設定（ActionCable）

### 2.1 Gem追加

`Gemfile` に追記：

```ruby
gem "redis", "~> 5.0"
```

```bash
bundle install
```

### 2.2 `config/cable.yml`

```yml
development:
  adapter: redis
  url: redis://localhost:6379/1

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>
  channel_prefix: blockjack_platform_production
```

---

## 3. ルーティング（UI + API + Cable）

`config/routes.rb`

```ruby
Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  root "lobby#index"

  resources :sessions, only: %i[create show] do
    post :join, on: :member
  end

  namespace :api do
    resources :sessions, only: %i[show]
  end
end
```

---

## 4. ディレクトリ構成（拡張性の核）

```bash
mkdir -p app/services/game
mkdir -p app/games/games/blockjack
```

---

## 5. DBモデル（最小）

### 5.1 Session（ゲームセッション）

```bash
bin/rails g model GameSession \
  game_key:string \
  status:integer \
  state:jsonb \
  version:integer \
  current_player_slot:integer \
  seed:string \
  winner_slot:integer
```

生成された migration を修正（デフォルト＆null制約）：

```ruby
# db/migrate/xxxxx_create_game_sessions.rb の中
t.string  :game_key, null: false
t.integer :status, null: false, default: 0
t.jsonb   :state,  null: false, default: {}
t.integer :version, null: false, default: 0
t.integer :current_player_slot
t.string  :seed, null: false
t.integer :winner_slot
add_index :game_sessions, :game_key
```

### 5.2 Participant（参加者）

```bash
bin/rails g model GameParticipant \
  game_session:references \
  slot:integer \
  display_name:string
```

migrationにユニーク制約：

```ruby
add_index :game_participants, [:game_session_id, :slot], unique: true
```

### 5.3 migrate

```bash
bin/rails db:migrate
```

---

## 6. モデル定義（enum / 関連）

### 6.1 `app/models/game_session.rb`

```ruby
class GameSession < ApplicationRecord
  has_many :game_participants, dependent: :destroy

  enum status: { waiting: 0, playing: 1, finished: 2 }

  validates :game_key, presence: true
  validates :seed, presence: true

  def players_count
    game_participants.count
  end
end
```

### 6.2 `app/models/game_participant.rb`

```ruby
class GameParticipant < ApplicationRecord
  belongs_to :game_session

  validates :slot, presence: true
  validates :display_name, presence: true
end
```

---

## 7. ゲームエンジン（BlockJack）

### 7.1 Engineファイル作成

`app/games/games/blockjack/engine.rb`

```ruby
# frozen_string_literal: true

module Games
  module BlockJack
    class Engine
      BOARD_SIZE = 4
      CENTER_CELLS = [[1, 1], [1, 2], [2, 1], [2, 2]].freeze # 0-index

      # ダイスは 6面の向き（上面/下面/北/南/東/西）を持つ
      # roll_north 等で回転
      def initialize(seed:)
        @rng = Random.new(seed.to_i(16) % (2**31 - 1))
      end

      def initial_state
        {
          "phase" => "placement",   # placement -> play -> finished
          "turn" => 1,              # 1 or 2
          "winner" => nil,
          "players" => {
            "1" => { "dice" => initial_dice_set },
            "2" => { "dice" => initial_dice_set }
          },
          "board" => empty_board,    # 4x4: nil or {owner, die_index, faces}
          "placed" => { "1" => [], "2" => [] } # 置いたdie_indexの配列
        }
      end

      # action:
      #  - {"type"=>"place","die_index"=>1..3,"pos"=>[r,c]}
      #  - {"type"=>"move","from"=>[r,c],"dir"=>"N|S|E|W"}
      def apply_action(state:, action:, actor_slot:)
        state = deep_dup(state)

        ensure_not_finished!(state)
        ensure_turn!(state, actor_slot)

        case action["type"]
        when "place"
          apply_place(state, actor_slot, action)
        when "move"
          apply_move(state, actor_slot, action)
        else
          raise "Unknown action type"
        end

        evaluate_and_advance!(state)
        state
      end

      # UI向け（本MVPはそのまま返す）
      def view_for(state:, viewer_slot:)
        state
      end

      private

      def deep_dup(obj)
        Marshal.load(Marshal.dump(obj))
      end

      def ensure_not_finished!(state)
        raise "Game finished" if state["phase"] == "finished"
      end

      def ensure_turn!(state, actor_slot)
        raise "Not your turn" if state["turn"].to_i != actor_slot.to_i
      end

      def empty_board
        Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE) }
      end

      def initial_dice_set
        # 3個のダイス。初期は「サイコロを振る」＝ランダムな向き + 上面値
        (1..3).map do |idx|
          faces = random_faces
          { "index" => idx, "faces" => faces }
        end
      end

      def random_faces
        # ちゃんとしたランダム回転を厳密にやるより、MVPでは「妥当な6面」を作る
        # top/bottomは相反、north/south、east/westも相反
        top = @rng.rand(1..6)
        bottom = opposite(top)
        # 残り4面は残値をシャッフルしてペア化
        rest = ([1,2,3,4,5,6] - [top, bottom]).shuffle(random: @rng)
        north, south, east, west = rest[0], rest[1], rest[2], rest[3]
        { "top" => top, "bottom" => bottom, "north" => north, "south" => south, "east" => east, "west" => west }
      end

      def opposite(n)
        7 - n
      end

      def apply_place(state, actor_slot, action)
        raise "Phase mismatch" unless state["phase"] == "placement"
        die_index = action.fetch("die_index").to_i
        r, c = action.fetch("pos")
        r = r.to_i; c = c.to_i

        unless CENTER_CELLS.include?([r,c])
          raise "Must place on center 4 cells"
        end
        raise "Cell occupied" if state["board"][r][c]

        placed = state["placed"][actor_slot.to_s]
        raise "Die already placed" if placed.include?(die_index)
        raise "Invalid die_index" unless (1..3).include?(die_index)

        die = state["players"][actor_slot.to_s]["dice"].find { |d| d["index"] == die_index }
        raise "Die not found" unless die

        state["board"][r][c] = {
          "owner" => actor_slot.to_i,
          "die_index" => die_index,
          "faces" => die["faces"]
        }
        placed << die_index

        # 3個置いたらプレイ開始
        if state["placed"]["1"].size == 3 && state["placed"]["2"].size == 3
          state["phase"] = "play"
        end
      end

      DIRS = {
        "N" => [-1, 0],
        "S" => [ 1, 0],
        "W" => [ 0,-1],
        "E" => [ 0, 1]
      }.freeze

      def apply_move(state, actor_slot, action)
        raise "Phase mismatch" unless state["phase"] == "play"
        from_r, from_c = action.fetch("from")
        dir = action.fetch("dir").to_s
        dr, dc = DIRS.fetch(dir)
        from_r = from_r.to_i; from_c = from_c.to_i

        cell = state["board"][from_r][from_c]
        raise "No piece" unless cell
        raise "Not yours" unless cell["owner"].to_i == actor_slot.to_i

        to_r = from_r + dr
        to_c = from_c + dc
        raise "Out of board" unless inside?(to_r, to_c)

        # 押し転がし：最大2個連なりまで
        chain = collect_chain(state["board"], from_r, from_c, dr, dc, max_len: 3) # 自分含め最大3セル（＝前に最大2個）
        # chainは [[r,c],[r,c]...] で、先頭が自分。次が押す対象1、さらに2…

        # 進行方向の最後の次のセルが盤外なら不可
        last_r, last_c = chain[-1]
        after_r = last_r + dr
        after_c = last_c + dc
        if !inside?(after_r, after_c) && chain.size > 1
          raise "Cannot push out of board"
        end

        # 空マスまでの押し込み処理（後ろから動かす）
        # chain.size==1ならただの移動（toが空かoccupiedならchainに含まれる）
        # まず、chain末尾の移動先を決める
        chain.reverse_each do |r,c|
          nr = r + dr
          nc = c + dc
          next if r == from_r && c == from_c && chain.size == 1 && state["board"][nr][nc] # 単純移動で塞がれてる場合はエラーにする
          if !inside?(nr, nc)
            # 盤外：押し出しは不可（上で弾いてる）のでここには来ない
            raise "Out of board"
          end
          # 移動先が chain 内の次セルならOK（後ろから処理してる）
          # 空マスでもOK
          state["board"][nr][nc] = roll_cell(state["board"][r][c], dir)
          state["board"][r][c] = nil
        end
      end

      def inside?(r,c)
        r.between?(0, BOARD_SIZE-1) && c.between?(0, BOARD_SIZE-1)
      end

      # 自分含めて、前方に連なるコマを最大max_lenまで集める
      def collect_chain(board, r, c, dr, dc, max_len:)
        chain = []
        cr, cc = r, c
        while chain.size < max_len
          cell = board[cr][cc]
          break unless cell
          chain << [cr, cc]
          nr = cr + dr
          nc = cc + dc
          break unless inside?(nr, nc)
          # 次が空ならここで止まる（chain末尾の次に空がある想定）
          break unless board[nr][nc]
          cr, cc = nr, nc
        end

        # 連なりがmax_lenに到達し、さらに次も埋まっている（=3個以上押し）ならNG
        if chain.size == max_len
          nr = cr + dr
          nc = cc + dc
          if inside?(nr, nc) && board[nr][nc]
            raise "Too many pieces in a row (max 2 push)"
          end
        end

        chain
      end

      def roll_cell(cell, dir)
        faces = cell["faces"]
        new_faces =
          case dir
          when "N" then roll_north(faces)
          when "S" then roll_south(faces)
          when "E" then roll_east(faces)
          when "W" then roll_west(faces)
          else
            raise "Bad dir"
          end

        cell.merge("faces" => new_faces)
      end

      def roll_north(f)
        # 北へ転がす：top<-south, south<-bottom, bottom<-north, north<-top
        { "top"=>f["south"], "bottom"=>f["north"], "north"=>f["top"], "south"=>f["bottom"], "east"=>f["east"], "west"=>f["west"] }
      end
      def roll_south(f)
        { "top"=>f["north"], "bottom"=>f["south"], "north"=>f["bottom"], "south"=>f["top"], "east"=>f["east"], "west"=>f["west"] }
      end
      def roll_east(f)
        { "top"=>f["west"], "bottom"=>f["east"], "east"=>f["top"], "west"=>f["bottom"], "north"=>f["north"], "south"=>f["south"] }
      end
      def roll_west(f)
        { "top"=>f["east"], "bottom"=>f["west"], "east"=>f["bottom"], "west"=>f["top"], "north"=>f["north"], "south"=>f["south"] }
      end

      def evaluate_and_advance!(state)
        # placement中は勝敗判定しない（両者3つ置いてplayへ）
        if state["phase"] == "play"
          s1 = score_for(state, 1)
          s2 = score_for(state, 2)

          if s1 == 11
            state["phase"] = "finished"
            state["winner"] = 1
            state["winner_slot"] = 1
            return
          end
          if s2 == 11
            state["phase"] = "finished"
            state["winner"] = 2
            state["winner_slot"] = 2
            return
          end

          # 相手が12以上になったら勝ち（自分のターン終了時）
          if state["turn"] == 1 && s2 >= 12
            state["phase"] = "finished"
            state["winner"] = 1
            state["winner_slot"] = 1
            return
          end
          if state["turn"] == 2 && s1 >= 12
            state["phase"] = "finished"
            state["winner"] = 2
            state["winner_slot"] = 2
            return
          end
        end

        # 手番交代（placementでも交代）
        state["turn"] = (state["turn"].to_i == 1 ? 2 : 1)
      end

      def score_for(state, owner)
        board = state["board"]
        sum = 0
        BOARD_SIZE.times do |r|
          BOARD_SIZE.times do |c|
            cell = board[r][c]
            next unless cell
            next unless cell["owner"].to_i == owner
            sum += cell["faces"]["top"].to_i
          end
        end
        sum
      end
    end
  end
end
```

---

## 8. レジストリ（将来のゲーム追加に備える）

`app/games/games/registry.rb`

```ruby
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
```

---

## 9. 共通サービス：状態更新（サーバー権威）

`app/services/game/apply_action.rb`

```ruby
# frozen_string_literal: true

module Game
  class ApplyAction
    class Error < StandardError; end
    class VersionMismatch < Error; end

    def self.call(session_id:, actor_slot:, action:, client_version:)
      GameSession.transaction do
        session = GameSession.lock.find(session_id)

        raise VersionMismatch, "version mismatch" if session.version != client_version.to_i

        engine_klass = Games::Registry.fetch(session.game_key)
        engine = engine_klass.new(seed: session.seed)

        new_state = engine.apply_action(state: session.state, action: action, actor_slot: actor_slot)

        session.state = new_state
        session.status =
          case new_state["phase"]
          when "placement" then :waiting
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

        ActionCable.server.broadcast("game_session:#{session.id}", payload)

        payload
      end
    end
  end
end
```

---

## 10. ActionCable Channel（ゲーム共通1本）

`app/channels/game_session_channel.rb`

```ruby
# frozen_string_literal: true

class GameSessionChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]
    stream_from "game_session:#{@session_id}"
  end

  def action(data)
    payload = Game::ApplyAction.call(
      session_id: @session_id,
      actor_slot: data["actor_slot"],
      action: data["action"],
      client_version: data["client_version"]
    )
    transmit(payload)
  rescue => e
    transmit(type: "error", message: e.message)
  end
end
```

---

## 11. UI（URLアクセスで遊ぶ：ロビー → セッション → 参加 → プレイ）

### 11.1 コントローラ作成

```bash
bin/rails g controller Lobby index
bin/rails g controller Sessions show
bin/rails g controller Api::Sessions show
```

### 11.2 `app/controllers/lobby_controller.rb`

```ruby
class LobbyController < ApplicationController
  def index
  end
end
```

### 11.3 `app/controllers/sessions_controller.rb`

```ruby
class SessionsController < ApplicationController
  def create
    seed = SecureRandom.hex(16)
    engine = Games::BlockJack::Engine.new(seed: seed)

    session = GameSession.create!(
      game_key: "blockjack",
      seed: seed,
      status: :waiting,
      state: engine.initial_state,
      current_player_slot: 1
    )

    redirect_to session_path(session)
  end

  def show
    @session = GameSession.find(params[:id])
  end

  def join
    session = GameSession.find(params[:id])

    # slot割当（1→2）
    slot = (session.game_participants.maximum(:slot) || 0) + 1
    raise ActionController::BadRequest, "Session is full" if slot > 2

    name = params[:display_name].presence || "Player#{slot}"

    session.game_participants.create!(slot: slot, display_name: name)

    # 参加者2人揃ったら開始：phaseは初期state内で placement だが、status表現は waiting/playingでも可
    # このMVPでは状態側の phase を正とする。3個ずつ置いたら play に入る。

    cookies.permanent.signed["bj_slot_#{session.id}"] = slot
    redirect_to session_path(session)
  end
end
```

### 11.4 `app/controllers/api/sessions_controller.rb`

```ruby
module Api
  class SessionsController < ApplicationController
    def show
      session = GameSession.find(params[:id])
      slot = cookies.signed["bj_slot_#{session.id}"]&.to_i
      render json: {
        session_id: session.id,
        slot: slot,
        state: session.state,
        version: session.version
      }
    end
  end
end
```

---

## 12. View（ERB）と素CSS

### 12.1 `app/views/lobby/index.html.erb`

```erb
<div class="container">
  <h1>BlockJack MVP</h1>

  <p>マッチングなし。部屋を作ってURLを共有して遊ぶ。</p>

  <%= button_to "新しい部屋を作る", sessions_path, method: :post, class: "btn" %>
</div>
```

### 12.2 `app/views/sessions/show.html.erb`

```erb
<div class="container">
  <h1>BlockJack</h1>

  <div class="row">
    <div class="card">
      <div class="label">Room URL</div>
      <input class="url" value="<%= request.url %>" readonly onclick="this.select()" />
      <div class="hint">相手にこのURLを送る</div>
    </div>

    <div class="card">
      <div class="label">Join</div>

      <% slot = cookies.signed["bj_slot_#{@session.id}"]&.to_i %>

      <% if slot.present? %>
        <div>あなたは Player <strong><%= slot %></strong></div>
      <% elsif @session.game_participants.count >= 2 %>
        <div>満員です（観戦MVPは未対応）</div>
      <% else %>
        <%= form_with url: join_session_path(@session), method: :post, local: true do |f| %>
          <input name="display_name" placeholder="名前（任意）" />
          <button class="btn" type="submit">参加する</button>
        <% end %>
      <% end %>
    </div>
  </div>

  <div id="app" data-session-id="<%= @session.id %>"></div>
</div>
```

### 12.3 `app/assets/stylesheets/application.css`

```css
/*
 *= require_tree .
 *= require_self
 */

:root {
  --bg: #0f1115;
  --fg: #e6e6e6;
  --muted: #a9b0bb;
  --card: #171a21;
  --border: #2a2f3a;
  --p1: #66d9ef;
  --p2: #f92672;
}

body { margin: 0; background: var(--bg); color: var(--fg); font-family: system-ui, -apple-system, Segoe UI, sans-serif; }
.container { max-width: 980px; margin: 24px auto; padding: 0 16px; }
h1 { margin: 0 0 12px; font-size: 26px; }
p { color: var(--muted); }

.row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin: 12px 0 18px; }
.card { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 12px; }
.label { color: var(--muted); font-size: 12px; margin-bottom: 6px; }
.hint { color: var(--muted); font-size: 12px; margin-top: 6px; }

.btn { background: #3b82f6; color: white; border: 0; padding: 10px 12px; border-radius: 8px; cursor: pointer; }
.btn:disabled { opacity: .6; cursor: not-allowed; }

input { width: 100%; padding: 10px 10px; border-radius: 8px; border: 1px solid var(--border); background: #0b0d12; color: var(--fg); }
input.url { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

.game { display: grid; grid-template-columns: 320px 1fr; gap: 12px; }
.panel { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 12px; }
.kv { display: grid; grid-template-columns: 120px 1fr; gap: 8px; margin: 6px 0; }
.badge { display: inline-block; padding: 2px 8px; border-radius: 99px; border: 1px solid var(--border); color: var(--muted); font-size: 12px; }
.badge.p1 { border-color: rgba(102,217,239,.4); color: var(--p1); }
.badge.p2 { border-color: rgba(249,38,114,.4); color: var(--p2); }

.board { display: grid; grid-template-columns: repeat(4, 70px); grid-template-rows: repeat(4, 70px); gap: 8px; margin-top: 10px; }
.cell { border: 1px solid var(--border); border-radius: 10px; display: flex; align-items: center; justify-content: center; background: #0b0d12; position: relative; user-select: none; cursor: pointer; }
.cell.center { outline: 1px dashed rgba(230,230,230,.2); }
.cell.selected { outline: 2px solid #3b82f6; }
.piece { width: 54px; height: 54px; border-radius: 12px; display:flex; align-items:center; justify-content:center; font-weight: 700; font-size: 22px; }
.piece.p1 { background: rgba(102,217,239,.18); border: 1px solid rgba(102,217,239,.5); color: var(--p1); }
.piece.p2 { background: rgba(249,38,114,.18); border: 1px solid rgba(249,38,114,.5); color: var(--p2); }
.small { color: var(--muted); font-size: 12px; }
.controls { display:flex; gap: 8px; flex-wrap: wrap; margin-top: 8px; }
.dirbtn { background: #111827; border: 1px solid var(--border); color: var(--fg); padding: 10px 12px; border-radius: 10px; cursor: pointer; }
.dirbtn:hover { border-color: rgba(59,130,246,.7); }

@media (max-width: 900px) {
  .row { grid-template-columns: 1fr; }
  .game { grid-template-columns: 1fr; }
}
```

---

## 13. JavaScript（esbuild）で画面を動かす

### 13.1 ActionCable consumer

Railsが生成済みの想定（なければ `bin/rails g channel X` で作成されるテンプレがある）。
`app/javascript/channels/consumer.js` を確認し、以下の形ならOK：

```js
import { createConsumer } from "@rails/actioncable"
export default createConsumer()
```

### 13.2 GameSession購読ヘルパ

`app/javascript/channels/game_session_channel.js`

```js
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
```

### 13.3 MVPアプリ本体

`app/javascript/application.js` を以下に置き換え：

```js
import { subscribeGameSession } from "./channels/game_session_channel"

const el = document.getElementById("app")
if (el) boot(el)

async function boot(root) {
  const sessionId = root.dataset.sessionId

  const res = await fetch(`/api/sessions/${sessionId}`)
  const initial = await res.json()

  let state = initial.state
  let version = initial.version
  const slot = initial.slot // 1/2/null
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

  function send(action) {
    if (!slot) return alert("先に参加してね")
    sub.action({
      actor_slot: slot,
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

  function render() {
    if (!state) return
    const [s1,s2] = scores()
    const phase = state.phase
    const turn = state.turn
    const winner = state.winner

    const myTurn = slot && turn === slot
    const canPlay = slot && (phase === "placement" || phase === "play")

    root.innerHTML = `
      <div class="game">
        <div class="panel">
          <div class="kv"><div class="small">あなた</div><div>${slot ? `Player ${slot}` : `未参加`}</div></div>
          <div class="kv"><div class="small">フェーズ</div><div><span class="badge">${phase}</span></div></div>
          <div class="kv"><div class="small">手番</div><div>
            <span class="badge ${turn===1 ? "p1": "p2"}">Player ${turn}</span>
            ${slot ? (myTurn ? "（あなた）" : "") : ""}
          </div></div>
          <div class="kv"><div class="small">スコア</div><div>
            <span class="badge p1">P1: ${s1}</span>
            <span class="badge p2">P2: ${s2}</span>
          </div></div>

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
      dieSelect.addEventListener("change", (e) => {
        selectedDie = parseInt(e.target.value,10)
      })
    }
  }

  function controlsHtml(phase, canPlay, myTurn) {
    if (!canPlay) return `<div class="small">操作不可</div>`
    if (!myTurn) return `<div class="small">相手の手番です</div>`

    if (phase === "placement") {
      return `
        <div class="small">初期配置：中央4マスに、自分のダイスを3つ置く（順番はどれでもOK）</div>
        <div class="controls">
          <select data-die class="dirbtn">
            <option value="1">die 1</option>
            <option value="2">die 2</option>
            <option value="3">die 3</option>
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
```

---

## 14. `sessions#create` 用のルートが必要（POST）

`SessionsController#create` を使うので、コントローラ作成時に `create` を含めてない場合は修正：

`app/controllers/sessions_controller.rb` はこの手順書の通りでOK。

---

## 15. 最後に起動

```bash
bin/dev
```

アクセス：
- `http://localhost:3000/`  
  「新しい部屋を作る」→ 生成されたURLを相手に送る → それぞれJoin → 置く→動かす

---

## 16. MVPの仕様メモ（割り切り）

- 初期配置：中央4マスに3個ずつ置く（置く順は自由）
- 押し転がし：最大2個連なりまで（3個以上連続はNG）
- 盤外に押し出すのは禁止
- 勝敗：
  - 自分の合計が **11ぴったり** で即勝ち
  - 自分のターン終了時点で相手の合計が **12以上** なら勝ち（「相手がオーバーしたら勝ち」）

---

## 17. 次にやりたくなる改善（必要になったら）

- placementの順序を「1→2→1→2…」で厳密にする / あるいは同時配置モードにする
- 観戦（slot=nilでもview_forで見せる）
- イベントログ（`game_events`）とリプレイ
- 乱数の厳密化（回転の群として一様にする）
- UIの当たり判定（自分の駒以外を選んだら警告、など）

---

## 参考情報
- `doc/rule.txt`
  - ゲームのルール
- `doc/board.pdf`
  - 紙に印字して遊ぶときのゲームボードデザイン


---

以上。MVPとしては十分遊べるはず。
