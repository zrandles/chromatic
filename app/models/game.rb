# Game model - manages Chromatic card game with 5 color-specific rules
class Game < ApplicationRecord
  include GameUtilities
  include CardValidation
  include CardPlay
  include AiStrategy

  has_many :color_paths, dependent: :destroy

  serialize :game_state, coder: JSON

  COLORS = %w[red blue green yellow purple].freeze
  TOTAL_ROUNDS = 10
  HAND_SIZE = 10 # Increased to allow multiple paths + extensions
  DECK_SIZE = 20 # 1-20 for each color

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

  # Check if round should end (called after AI finishes playing)
  def check_round_end
    game_state['consecutive_passes'] ||= 0
    consecutive_passes = game_state['consecutive_passes']
    deck = game_state['deck']

    deck_empty = deck.empty?
    hands_empty = player_hand.empty? && ai_hand.empty?
    both_stuck = consecutive_passes >= 6

    end_round if hands_empty || (deck_empty && both_stuck) || both_stuck

    save
  end

  # Player plays a card, then AI responds with full turn
  def handle_player_card_play(card_index, color)
    result = play_card(card_index, color, 'player')
    return result unless result[:success]

    # AI plays full turn after player
    ai_play_full_turn

    result
  end

  # Handle end turn: auto-discard remaining cards, AI plays full turn
  def handle_end_turn
    # Auto-discard all remaining cards if deck has cards
    if game_state['deck'].any?
      discard_all_and_draw('player')
    else
      # Deck empty, just clear hand
      player_hand.clear
    end

    # AI plays full turn
    ai_play_full_turn

    save
  end

  # Bulk discard-and-draw operation (more efficient than looping)
  def discard_all_and_draw(player_type = 'player')
    hand = player_type == 'player' ? player_hand : ai_hand
    discard_count = hand.length

    # Clear hand
    hand.clear

    # Draw new cards (up to deck size)
    drew_count = 0
    discard_count.times do
      drawn = draw_card(save_after: false)
      if drawn
        hand << drawn
        drew_count += 1
      else
        break  # Deck empty
      end
    end

    # Reset consecutive passes since player took action
    game_state['consecutive_passes'] = 0

    save
    { success: true, discarded: discard_count, drew: drew_count }
  end

  # Clear hand for a player (used when deck is empty)
  def clear_hand(player_type = 'player')
    hand = player_type == 'player' ? player_hand : ai_hand
    hand.clear
    save
  end

  def end_round
    # Calculate base scores for this round
    player_base_score = player_paths.sum(:score)
    ai_base_score = ai_paths.sum(:score)

    # Calculate long path bonuses
    player_bonus = player_paths.sum { |path| calculate_long_path_bonus(path.cards.length) }
    ai_bonus = ai_paths.sum { |path| calculate_long_path_bonus(path.cards.length) }

    # Apply combo multipliers based on number of paths completed
    player_path_count = player_paths.count
    ai_path_count = ai_paths.count

    player_multiplier = calculate_combo_multiplier(player_path_count)
    ai_multiplier = calculate_combo_multiplier(ai_path_count)

    # Total score = (base + bonus) * multiplier
    round_player_score = ((player_base_score + player_bonus) * player_multiplier).to_i
    round_ai_score = ((ai_base_score + ai_bonus) * ai_multiplier).to_i

    # Store round summary in game_state
    game_state['round_summary'] = build_round_summary(
      round_player_score, round_ai_score,
      player_base_score, ai_base_score,
      player_bonus, ai_bonus,
      player_multiplier, ai_multiplier,
      player_path_count, ai_path_count
    )

    # Update total scores
    self.player_score += round_player_score
    self.ai_score += round_ai_score

    # Set status based on game state
    update_game_status

    save
  end

  private

  def build_round_summary(round_player_score, round_ai_score,
                         player_base_score, ai_base_score,
                         player_bonus, ai_bonus,
                         player_multiplier, ai_multiplier,
                         player_path_count, ai_path_count)
    {
      'round' => current_round,
      'player_round_score' => round_player_score,
      'ai_round_score' => round_ai_score,
      'player_base_score' => player_base_score,
      'ai_base_score' => ai_base_score,
      'player_bonus' => player_bonus,
      'ai_bonus' => ai_bonus,
      'player_multiplier' => player_multiplier,
      'ai_multiplier' => ai_multiplier,
      'player_path_count' => player_path_count,
      'ai_path_count' => ai_path_count,
      'player_total_before' => player_score,
      'ai_total_before' => ai_score
    }
  end

  def update_game_status
    deck_depleted = game_state['deck'].empty?
    max_rounds_reached = current_round >= total_rounds

    self.status = if deck_depleted || max_rounds_reached
                    'finished'
                  else
                    'round_ending'
                  end
  end

  public

  def continue_to_next_round
    # Clear round summary
    game_state['round_summary'] = nil

    # Advance to next round
    self.current_round += 1
    self.status = 'active'

    # CRITICAL GAME DESIGN CHANGE: Paths persist between rounds!
    # This creates:
    # - Long-term strategy (commit to colors early, extend over multiple rounds)
    # - Resource scarcity (deck gets smaller each round)
    # - Meaningful decisions (starting Purple in Round 1 affects entire game)
    #
    # OLD BEHAVIOR (BAD): Paths cleared, deck reset → no continuity
    # NEW BEHAVIOR (GOOD): Paths stay, deck persists → strategic depth

    # Deck persists (cards get scarce as game progresses)
    # DO NOT reset deck - this is intentional!

    # Refill hands from existing deck
    game_state['player_hand'] = draw_hand
    game_state['ai_hand'] = draw_hand
    game_state['turn'] = 'player'

    save
  end

  def winner
    return nil unless status == 'finished'
    return 'player' if player_score > ai_score
    return 'ai' if ai_score > player_score
    'tie'
  end

  # SECURITY: Validate game state integrity to prevent tampering
  def valid_game_state?
    return false unless game_state.is_a?(Hash)

    # Validate required keys exist
    required_keys = %w[deck player_hand ai_hand turn]
    return false unless required_keys.all? { |key| game_state.key?(key) }

    # Validate deck is an array
    return false unless game_state['deck'].is_a?(Array)

    # Validate hands are arrays
    return false unless game_state['player_hand'].is_a?(Array)
    return false unless game_state['ai_hand'].is_a?(Array)

    # Validate turn is valid
    return false unless %w[player ai].include?(game_state['turn'])

    # Validate all cards in deck have required structure
    game_state['deck'].each do |card|
      return false unless card.is_a?(Hash)
      return false unless card['color'].present? && card['number'].present?
      return false unless COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= DECK_SIZE
    end

    # Validate all cards in player hand
    game_state['player_hand'].each do |card|
      return false unless card.is_a?(Hash)
      return false unless card['color'].present? && card['number'].present?
      return false unless COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= DECK_SIZE
    end

    # Validate all cards in AI hand
    game_state['ai_hand'].each do |card|
      return false unless card.is_a?(Hash)
      return false unless card['color'].present? && card['number'].present?
      return false unless COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= DECK_SIZE
    end

    # Validate scores are non-negative
    return false if player_score.negative? || ai_score.negative?

    # Validate round numbers are valid
    return false if current_round < 1 || current_round > total_rounds

    # Validate status
    return false unless %w[active round_ending finished].include?(status)

    true
  end
end
