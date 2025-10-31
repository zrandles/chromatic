# AI strategy logic - extracted for testability and clarity
module AiStrategy
  extend ActiveSupport::Concern

  def ai_play
    hand = ai_hand
    return nil if hand.empty?

    best_move = find_best_move(hand)

    # Execute best move and return true/nil to indicate success
    if best_move
      play_card(best_move[:card_idx], best_move[:color], 'ai')
      true  # Indicate AI played a card successfully
    else
      nil  # No valid move found
    end
  end

  # AI plays all possible moves in sequence
  def ai_play_full_turn
    max_plays = 20  # Safety limit to prevent infinite loops
    plays = 0

    while plays < max_plays
      break unless ai_play  # Stop when AI can't find valid move
      plays += 1
    end

    # After AI finishes, check if round should end
    check_round_end
  end

  private

  def find_best_move(hand)
    best_move = nil
    best_score = -1

    # Evaluate extending existing paths (prioritize high-value moves)
    extend_move = evaluate_path_extensions(hand)
    if extend_move && extend_move[:score] > best_score
      best_score = extend_move[:score]
      best_move = extend_move[:move]
    end

    # Evaluate starting new paths (balanced strategy: multiple paths for combos)
    start_move = evaluate_new_paths(hand)
    if start_move && start_move[:score] > best_score
      best_score = start_move[:score]
      best_move = start_move[:move]
    end

    best_move
  end

  def evaluate_path_extensions(hand)
    best_move = nil
    best_score = -1
    ai_paths_collection = color_paths.where(player_type: 'ai')
    path_count = ai_paths_collection.count

    ai_paths_collection.each do |path|
      path_cards = JSON.parse(path.cards_data)
      path_color = path.color

      hand.each_with_index do |card, card_idx|
        next unless validate_card_play(card, path_cards, path_color)[:valid]

        # Score this move based on score gain and path bonuses
        current_score = path_cards.length ** 2
        new_score = (path_cards.length + 1) ** 2
        score_gain = new_score - current_score

        # Bonus for completing paths to encourage multiple paths (combo multiplier)
        path_bonus = path_count * 2
        move_value = score_gain + path_bonus

        if move_value > best_score
          best_score = move_value
          best_move = { type: :extend, card_idx: card_idx, color: path_color }
        end
      end
    end

    best_move ? { move: best_move, score: best_score } : nil
  end

  def evaluate_new_paths(hand)
    current_ai_path_count = color_paths.where(player_type: 'ai').count
    start_cost = starting_cost_for_path_number(current_ai_path_count)

    return nil if hand.length < start_cost + 1  # +1 for the card being played

    best_move = nil
    best_score = -1

    # Group cards by color to find best starting options
    color_counts = hand.group_by { |card| card['color'] }.transform_values(&:count)

    # Prioritize colors where we have multiple cards (better path potential)
    color_counts.each do |card_color, count|
      # Check if we already have this path (diversity bonus for new colors)
      existing_path = color_paths.find_by(color: card_color, player_type: 'ai')

      diversity_bonus = existing_path ? 0 : 10  # Big bonus for starting new colors
      move_value = count * 3 + diversity_bonus

      if move_value > best_score
        best_score = move_value
        card_idx = hand.index { |card| card['color'] == card_color }
        best_move = { type: :start, card_idx: card_idx, color: card_color }
      end
    end

    best_move ? { move: best_move, score: best_score } : nil
  end
end
