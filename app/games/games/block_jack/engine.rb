# frozen_string_literal: true

module Games
  module BlockJack
    class Engine
      BOARD_SIZE = 4
      CENTER_CELLS = [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ], [ 2, 2 ] ].freeze

      def initialize(seed:)
        @rng = Random.new(seed.to_i(16) % (2**31 - 1))
      end

      def initial_state
        {
          "phase" => "waiting_for_players",
          "turn" => nil,
          "winner" => nil,
          "players" => {},
          "dice_roll" => {},
          "board" => empty_board,
          "placed" => { "1" => [], "2" => [] }
        }
      end

      def add_player(state:, slot:)
        state = deep_dup(state)
        raise "Game already started" unless state["phase"] == "waiting_for_players"

        state["players"][slot.to_s] = {}

        if state["players"].size == 2
          state["phase"] = "dice_roll"
        end

        state
      end

      def apply_action(state:, action:, actor_slot:)
        state = deep_dup(state)
        ensure_not_finished!(state)

        case action["type"]
        when "roll_dice"
          apply_roll_dice(state, actor_slot)
        when "place"
          ensure_turn!(state, actor_slot)
          apply_place(state, actor_slot, action)
          evaluate_and_advance!(state)
        when "move"
          ensure_turn!(state, actor_slot)
          apply_move(state, actor_slot, action)
          evaluate_and_advance!(state)
        else
          raise "Unknown action type"
        end

        state
      end

      def view_for(state:, viewer_slot:)
        state
      end

      private

      def deep_dup(obj)
        JSON.parse(JSON.generate(obj))
      end

      def ensure_not_finished!(state)
        raise "Game finished" if state["phase"] == "finished"
      end

      def ensure_turn!(state, actor_slot)
        raise "Not your turn" if state["turn"].to_i != actor_slot.to_i
      end

      def apply_roll_dice(state, actor_slot)
        raise "Phase mismatch" unless state["phase"] == "dice_roll"
        slot_key = actor_slot.to_s

        if state["dice_roll"].key?("result")
          state["dice_roll"] = {}
        end

        raise "Already rolled" if state["dice_roll"][slot_key]

        dice_values = 3.times.map { SecureRandom.random_number(1..6) }
        state["dice_roll"][slot_key] = {
          "dice" => dice_values,
          "sum" => dice_values.sum,
          "max" => dice_values.max
        }

        if state["dice_roll"]["1"] && state["dice_roll"]["2"]
          resolve_dice_roll!(state)
        end
      end

      def resolve_dice_roll!(state)
        roll1 = state["dice_roll"]["1"]
        roll2 = state["dice_roll"]["2"]

        first_player = compare_dice_rolls(roll1, roll2)

        if first_player.nil?
          state["dice_roll"] = { "result" => "tie" }
          return
        end

        state["dice_roll"]["result"] = "resolved"
        state["dice_roll"]["first_player"] = first_player
        state["turn"] = first_player
        state["phase"] = "placement"
        state["players"]["1"] = { "dice" => initial_dice_set }
        state["players"]["2"] = { "dice" => initial_dice_set }
      end

      def compare_dice_rolls(roll1, roll2)
        if roll1["sum"] > roll2["sum"]
          1
        elsif roll1["sum"] < roll2["sum"]
          2
        elsif roll1["max"] > roll2["max"]
          1
        elsif roll1["max"] < roll2["max"]
          2
        end
      end

      def empty_board
        Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE) }
      end

      def initial_dice_set
        (1..3).map do |idx|
          faces = random_faces
          { "index" => idx, "faces" => faces }
        end
      end

      def random_faces
        top = @rng.rand(1..6)
        bottom = opposite(top)
        rest = ([ 1, 2, 3, 4, 5, 6 ] - [ top, bottom ]).shuffle(random: @rng)
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

        unless CENTER_CELLS.include?([ r, c ])
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

        if state["placed"]["1"].size == 3 && state["placed"]["2"].size == 3
          state["phase"] = "play"
        end
      end

      DIRS = {
        "N" => [ -1, 0 ],
        "S" => [ 1, 0 ],
        "W" => [ 0, -1 ],
        "E" => [ 0, 1 ]
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

        chain = collect_chain(state["board"], from_r, from_c, dr, dc, max_len: 3)

        last_r, last_c = chain[-1]
        after_r = last_r + dr
        after_c = last_c + dc
        if !inside?(after_r, after_c) && chain.size > 1
          raise "Cannot push out of board"
        end

        chain.reverse_each do |r, c|
          nr = r + dr
          nc = c + dc
          next if r == from_r && c == from_c && chain.size == 1 && state["board"][nr][nc]
          if !inside?(nr, nc)
            raise "Out of board"
          end
          state["board"][nr][nc] = roll_cell(state["board"][r][c], dir)
          state["board"][r][c] = nil
        end
      end

      def inside?(r, c)
        r.between?(0, BOARD_SIZE-1) && c.between?(0, BOARD_SIZE-1)
      end

      def collect_chain(board, r, c, dr, dc, max_len:)
        chain = []
        cr, cc = r, c
        while chain.size < max_len
          cell = board[cr][cc]
          break unless cell
          chain << [ cr, cc ]
          nr = cr + dr
          nc = cc + dc
          break unless inside?(nr, nc)
          break unless board[nr][nc]
          cr, cc = nr, nc
        end

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
