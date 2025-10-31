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
end
