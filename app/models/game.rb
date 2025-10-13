class Game < ApplicationRecord
  has_many :color_paths, dependent: :destroy

  serialize :game_state, coder: JSON

  COLORS = %w[red blue green yellow purple].freeze
  TOTAL_ROUNDS = 10
  HAND_SIZE = 7
  DECK_SIZE = 20 # 1-20 for each color
  START_PATH_COST = 3 # cards

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

    # Check if starting a new path
    path = color_paths.find_by(color: color, player_type: player_type)

    if path.nil?
      # Validate card color matches path color when starting new path
      if card['color'] != color
        return { success: false, error: "Card color must match path color. This #{card['color']} card cannot start a #{color} path." }
      end

      # Starting new path costs 3 cards
      if hand.length < START_PATH_COST
        return { success: false, error: 'Need 3 cards to start a path' }
      end

      # Discard 2 additional cards
      cards_to_discard = [card_index]
      2.times do
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
      # Must ascend with jumps (no consecutive)
      return { valid: false, error: 'Red must ascend' } unless new_num > numbers.last
      return { valid: false, error: 'Red cannot have consecutive numbers' } if new_num == numbers.last + 1
    when 'blue'
      # Waves (alternating up/down)
      if numbers.length >= 2
        last_direction = numbers[-1] > numbers[-2] ? 'up' : 'down'
        new_direction = new_num > numbers.last ? 'up' : 'down'
        return { valid: false, error: 'Blue must wave (alternate up/down)' } if last_direction == new_direction
      end
    when 'green'
      # Consecutive numbers only
      return { valid: false, error: 'Green must be consecutive' } unless (new_num - numbers.last).abs == 1
    when 'yellow'
      # Solo cards - only one card per path
      return { valid: false, error: 'Yellow can only have one card' } if numbers.length >= 1
    when 'purple'
      # Descends exponentially (each card should be roughly half previous)
      return { valid: false, error: 'Purple must descend' } unless new_num < numbers.last
      # For simplicity, just require significant decrease
      return { valid: false, error: 'Purple must decrease significantly' } unless new_num <= numbers.last * 0.7
    end

    { valid: true }
  end

  def end_turn
    if game_state['turn'] == 'player'
      # AI turn
      ai_play
      game_state['turn'] = 'player'
    else
      game_state['turn'] = 'ai'
    end

    # Check if round is over (both players out of cards or deck empty)
    if player_hand.empty? || ai_hand.empty? || game_state['deck'].empty?
      end_round
    end

    save
  end

  def ai_play
    # Simple AI: Try to play any valid card
    hand = ai_hand

    # Try adding to existing paths first
    color_paths.where(player_type: 'ai').each do |path|
      hand.each_with_index do |card, idx|
        cards = JSON.parse(path.cards_data)
        if validate_card_play(card, cards, path.color)[:valid]
          play_card(idx, path.color, 'ai')
          return
        end
      end
    end

    # Try starting a new path if we have enough cards
    if hand.length >= START_PATH_COST
      card = hand[0]
      play_card(0, card['color'], 'ai')
    end
  end

  def end_round
    # Calculate scores for this round
    round_player_score = player_paths.sum(:score)
    round_ai_score = ai_paths.sum(:score)

    # Store round summary in game_state
    game_state['round_summary'] = {
      'round' => current_round,
      'player_round_score' => round_player_score,
      'ai_round_score' => round_ai_score,
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
