class Game < ApplicationRecord
  has_many :color_paths, dependent: :destroy

  serialize :game_state, coder: JSON

  COLORS = %w[red blue green yellow purple].freeze
  TOTAL_ROUNDS = 10
  HAND_SIZE = 10 # Increased to allow multiple paths + extensions
  DECK_SIZE = 20 # 1-20 for each color
  START_PATH_COST = 2 # cards (1 played + 1 discarded)

  after_initialize :setup_new_game, if: :new_record?

  def setup_new_game
    self.status ||= 'active'
    self.current_round ||= 1
    self.total_rounds ||= TOTAL_ROUNDS
    self.player_score ||= 0
    self.ai_score ||= 0

    unless game_state
      # Initialize game_state with deck FIRST so draw_hand can access it
      self.game_state = {
        'deck' => create_deck,
        'player_hand' => [],
        'ai_hand' => [],
        'turn' => 'player'
      }

      # Now draw hands - game_state['deck'] is accessible
      self.game_state['player_hand'] = draw_hand
      self.game_state['ai_hand'] = draw_hand
    end
  end

  def create_deck
    deck = []
    COLORS.each do |color|
      (1..DECK_SIZE).each do |number|
        deck << { 'color' => color, 'number' => number }
      end
    end
    deck.shuffle
  end

  def draw_hand
    cards = []
    HAND_SIZE.times do
      cards << draw_card(save_after: false)
    end
    cards
  end

  def draw_card(save_after: true)
    deck = game_state['deck']
    return nil if deck.empty?
    card = deck.shift
    save if save_after
    card
  end

  def player_hand
    game_state['player_hand']
  end

  def ai_hand
    game_state['ai_hand']
  end

  def player_paths
    color_paths.where(player_type: 'player')
  end

  def ai_paths
    color_paths.where(player_type: 'ai')
  end

  def play_card(card_index, color, player_type = 'player')
    hand = player_type == 'player' ? player_hand : ai_hand
    card = hand[card_index]
    return { success: false, error: 'Invalid card' } unless card

    # Reset consecutive passes when a card is successfully played
    game_state['consecutive_passes'] = 0

    # Check if starting a new path
    path = color_paths.find_by(color: color, player_type: player_type)

    if path.nil?
      # Validate card color matches path color when starting new path
      if card['color'] != color
        return { success: false, error: "Card color must match path color. This #{card['color']} card cannot start a #{color} path." }
      end

      # Starting new path costs START_PATH_COST cards
      if hand.length < START_PATH_COST
        return { success: false, error: "Need #{START_PATH_COST} cards to start a path" }
      end

      # Discard additional cards (total START_PATH_COST)
      cards_to_discard = [card_index]
      (START_PATH_COST - 1).times do
        idx = (0...hand.length).to_a.reject { |i| cards_to_discard.include?(i) }.sample
        cards_to_discard << idx
      end

      # Remove cards from hand (remove in reverse order to maintain indices)
      cards_to_discard.sort.reverse.each { |idx| hand.delete_at(idx) }

      # Create new path
      path = color_paths.create!(
        color: color,
        player_type: player_type,
        cards_data: [card].to_json,
        score: 1 # (1 card)^2 = 1
      )

      # Draw cards to refill hand
      drew_count = 0
      cards_to_discard.length.times do
        drawn = draw_card
        if drawn
          hand << drawn
          drew_count += 1
        end
      end

      save
      return { success: true, path: path, drew_cards: drew_count }
    else
      # Adding to existing path
      cards = JSON.parse(path.cards_data)

      # Validate the play
      validation = validate_card_play(card, cards, color)
      unless validation[:valid]
        return { success: false, error: validation[:error] }
      end

      # Add card to path
      cards << card
      path.update!(
        cards_data: cards.to_json,
        score: cards.length ** 2 # (cards)^2
      )

      # Remove card from hand
      hand.delete_at(card_index)

      # Draw a card
      drew_count = 0
      drawn = draw_card
      if drawn
        hand << drawn
        drew_count = 1
      end

      save
      return { success: true, path: path, drew_cards: drew_count }
    end
  end

  def validate_card_play(card, existing_cards, color)
    return { valid: false, error: 'Wrong color' } unless card['color'] == color

    numbers = existing_cards.map { |c| c['number'] }
    new_num = card['number']

    case color
    when 'red'
      # Must ascend with jumps of 2+ (risk/reward: harder but can reach 8 cards)
      return { valid: false, error: 'Red must ascend' } unless new_num > numbers.last
      return { valid: false, error: 'Red must jump by at least 2' } if new_num - numbers.last < 2
      return { valid: false, error: 'Red maxes out at 8 cards' } if numbers.length >= 8
    when 'blue'
      # Pairs with flexibility: complete pairs, then can extend or start new pair
      # Strategic: save pairs, decide between longer paths vs starting new colors
      if numbers.length.odd?
        # Must complete the pair OR extend if last pair is complete (consecutive to last number)
        is_matching_pair = new_num == numbers.last
        is_consecutive = (new_num - numbers.last).abs == 1
        return { valid: false, error: 'Blue must complete pair or extend consecutively' } unless is_matching_pair || is_consecutive
      else
        # Starting new pair: can play any number except same as last pair's first card
        if numbers.length >= 2
          return { valid: false, error: 'Blue cannot repeat the previous pair' } if new_num == numbers[-2]
        end
      end
      return { valid: false, error: 'Blue maxes out at 10 cards' } if numbers.length >= 10
    when 'green'
      # Consecutive with reasonable cap
      return { valid: false, error: 'Green must be consecutive' } unless (new_num - numbers.last).abs == 1
      return { valid: false, error: 'Green maxes out at 6 cards' } if numbers.length >= 6
    when 'yellow'
      # Ascending by 1s (1,2,3,4...) - creates strategic sequencing decisions
      if numbers.any?
        return { valid: false, error: 'Yellow must ascend by exactly 1' } unless new_num == numbers.last + 1
      end
      return { valid: false, error: 'Yellow maxes out at 8 cards' } if numbers.length >= 8
    when 'purple'
      # Descending by ANY amount (easier to build, no cap for balance)
      return { valid: false, error: 'Purple must descend' } unless new_num < numbers.last
    end

    { valid: true }
  end

  def discard_and_draw(card_index, player_type = 'player')
    hand = player_type == 'player' ? player_hand : ai_hand
    return { success: false, error: 'Invalid card' } unless hand[card_index]
    return { success: false, error: 'Deck is empty' } if game_state['deck'].empty?

    # Discard the card
    hand.delete_at(card_index)

    # Draw a new card
    drawn = draw_card
    if drawn
      hand << drawn
      # Reset consecutive passes since player took an action
      game_state['consecutive_passes'] = 0
      save
      { success: true, card: drawn }
    else
      { success: false, error: 'Could not draw card' }
    end
  end

  def end_turn
    if game_state['turn'] == 'player'
      # AI turn
      ai_play
      game_state['turn'] = 'player'
    else
      game_state['turn'] = 'ai'
    end

    # Check if round is over
    # Round ends when: hands are empty, deck is empty, OR both players have passed 3 times in a row (stuck)
    game_state['consecutive_passes'] ||= 0
    game_state['consecutive_passes'] += 1

    if player_hand.empty? || ai_hand.empty? || game_state['deck'].empty? || game_state['consecutive_passes'] >= 6
      end_round
    end

    save
  end

  def ai_play
    # Improved AI: Strategic card play with scoring evaluation
    hand = ai_hand
    return if hand.empty?

    best_move = nil
    best_score = -1

    # Evaluate extending existing paths (prioritize high-value moves)
    color_paths.where(player_type: 'ai').each do |path|
      hand.each_with_index do |card, idx|
        cards = JSON.parse(path.cards_data)
        if validate_card_play(card, cards, path.color)[:valid]
          # Score this move based on:
          # 1. Score gain (new_score - old_score)
          # 2. Path length (longer paths are more valuable)
          current_score = cards.length ** 2
          new_score = (cards.length + 1) ** 2
          score_gain = new_score - current_score

          # Bonus for completing paths to encourage multiple paths (combo multiplier)
          path_bonus = color_paths.where(player_type: 'ai').count * 2

          move_value = score_gain + path_bonus

          if move_value > best_score
            best_score = move_value
            best_move = { type: :extend, card_idx: idx, color: path.color }
          end
        end
      end
    end

    # Evaluate starting new paths (balanced strategy: multiple paths for combos)
    if hand.length >= START_PATH_COST
      # Group cards by color to find best starting options
      color_counts = hand.group_by { |c| c['color'] }.transform_values(&:count)

      # Prioritize colors where we have multiple cards (better path potential)
      color_counts.each do |color, count|
        # Score based on:
        # 1. Number of cards we have in this color (more = better path potential)
        # 2. Whether we already have this path (diversity bonus for new colors)
        existing_path = color_paths.find_by(color: color, player_type: 'ai')

        diversity_bonus = existing_path ? 0 : 10  # Big bonus for starting new colors
        move_value = count * 3 + diversity_bonus

        if move_value > best_score
          best_score = move_value
          card_idx = hand.index { |c| c['color'] == color }
          best_move = { type: :start, card_idx: card_idx, color: color }
        end
      end
    end

    # Execute best move
    if best_move
      play_card(best_move[:card_idx], best_move[:color], 'ai')
    end
  end

  def end_round
    # Calculate base scores for this round
    player_base_score = player_paths.sum(:score)
    ai_base_score = ai_paths.sum(:score)

    # Apply combo multipliers based on number of paths completed
    player_path_count = player_paths.count
    ai_path_count = ai_paths.count

    player_multiplier = calculate_combo_multiplier(player_path_count)
    ai_multiplier = calculate_combo_multiplier(ai_path_count)

    round_player_score = (player_base_score * player_multiplier).to_i
    round_ai_score = (ai_base_score * ai_multiplier).to_i

    # Store round summary in game_state
    game_state['round_summary'] = {
      'round' => current_round,
      'player_round_score' => round_player_score,
      'ai_round_score' => round_ai_score,
      'player_base_score' => player_base_score,
      'ai_base_score' => ai_base_score,
      'player_multiplier' => player_multiplier,
      'ai_multiplier' => ai_multiplier,
      'player_path_count' => player_path_count,
      'ai_path_count' => ai_path_count,
      'player_total_before' => player_score,
      'ai_total_before' => ai_score
    }

    # Update total scores
    self.player_score += round_player_score
    self.ai_score += round_ai_score

    # Set status to show round summary
    if current_round >= total_rounds
      self.status = 'finished'
    else
      self.status = 'round_ending'
    end

    save
  end

  def calculate_combo_multiplier(path_count)
    # Reward playing multiple colors, but balanced to not dominate path length strategy
    # 1 path = 1.0x (base)
    # 2 paths = 1.2x (+20%)
    # 3 paths = 1.4x (+40%)
    # 4 paths = 1.7x (+70%)
    # 5 paths = 2.0x (+100%) - RAINBOW BONUS!
    case path_count
    when 0, 1
      1.0
    when 2
      1.2
    when 3
      1.4
    when 4
      1.7
    when 5
      2.0  # Rainbow bonus!
    else
      2.0
    end
  end

  def continue_to_next_round
    # Clear round summary
    game_state['round_summary'] = nil

    # Advance to next round
    self.current_round += 1
    self.status = 'active'

    # Reset for next round
    color_paths.destroy_all
    game_state['player_hand'] = draw_hand
    game_state['ai_hand'] = draw_hand
    game_state['deck'] = create_deck
    game_state['turn'] = 'player'

    save
  end

  def winner
    return nil unless status == 'finished'
    return 'player' if player_score > ai_score
    return 'ai' if ai_score > player_score
    'tie'
  end
end
