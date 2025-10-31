# Utility methods for game logic - extracted for testability and reusability
module GameUtilities
  extend ActiveSupport::Concern

  # Dynamic starting costs for paths
  # 1st path: FREE, 2nd: 1 card, 3rd: 2 cards, 4th: 3 cards, 5th: 4 cards
  def starting_cost_for_path_number(path_count)
    return 0 if path_count == 0  # First path is free!
    return 1 if path_count == 1
    return 2 if path_count == 2
    return 3 if path_count == 3
    return 4 if path_count >= 4
    path_count  # fallback
  end

  # Calculate combo multiplier based on number of paths
  # Reduced multipliers for balance
  def calculate_combo_multiplier(path_count)
    case path_count
    when 0, 1
      1.0
    when 2
      1.1
    when 3
      1.25
    when 4
      1.4
    when 5
      1.6
    else
      1.6
    end
  end

  # Calculate bonus points for long paths
  # 5+ cards: +5 pts, 7+ cards: +10 pts, 10+ cards: +20 pts
  def calculate_long_path_bonus(path_length)
    return 20 if path_length >= 10
    return 10 if path_length >= 7
    return 5 if path_length >= 5
    0
  end

  # Create a shuffled deck of cards
  def create_deck
    deck = []
    Game::COLORS.each do |color|
      (1..Game::DECK_SIZE).each do |number|
        deck << { 'color' => color, 'number' => number }
      end
    end
    deck.shuffle
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
      return false unless Game::COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= Game::DECK_SIZE
    end

    # Validate all cards in player hand
    game_state['player_hand'].each do |card|
      return false unless card.is_a?(Hash)
      return false unless card['color'].present? && card['number'].present?
      return false unless Game::COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= Game::DECK_SIZE
    end

    # Validate all cards in AI hand
    game_state['ai_hand'].each do |card|
      return false unless card.is_a?(Hash)
      return false unless card['color'].present? && card['number'].present?
      return false unless Game::COLORS.include?(card['color'])
      return false unless card['number'].is_a?(Integer) && card['number'] >= 1 && card['number'] <= Game::DECK_SIZE
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
