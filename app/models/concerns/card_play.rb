# Card play logic - handles playing cards to paths
module CardPlay
  extend ActiveSupport::Concern

  def play_card(card_index, color, player_type = 'player')
    hand = player_hand_for(player_type)
    card = hand[card_index]
    return { success: false, error: 'Invalid card' } unless card

    # Reset consecutive passes when a card is successfully played
    game_state['consecutive_passes'] = 0

    # Check if starting a new path or extending existing path
    path = color_paths.find_by(color: color, player_type: player_type)

    if path.nil?
      start_new_path(card_index, color, player_type, hand, card)
    else
      extend_existing_path(card_index, path, hand, card)
    end
  end

  private

  def player_hand_for(player_type)
    player_type == 'player' ? player_hand : ai_hand
  end

  def start_new_path(card_index, color, player_type, hand, card)
    # Validate card color matches path color when starting new path
    if card['color'] != color
      return { success: false, error: "Card color must match path color. This #{card['color']} card cannot start a #{color} path." }
    end

    # Dynamic starting cost based on number of existing paths
    current_path_count = color_paths.where(player_type: player_type).count
    start_cost = starting_cost_for_path_number(current_path_count)
    required_cards = start_cost + 1  # +1 for the card being played

    if hand.length < required_cards
      return { success: false, error: "Need #{required_cards} cards to start path ##{current_path_count + 1}" }
    end

    # Discard additional cards (total start_cost, not including played card)
    cards_to_discard = select_cards_to_discard(hand, card_index, start_cost)

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
    drew_count = refill_hand(hand, cards_to_discard.length)

    save
    { success: true, path: path, drew_cards: drew_count }
  end

  def extend_existing_path(card_index, path, hand, card)
    cards = JSON.parse(path.cards_data)

    # Validate the play
    validation = validate_card_play(card, cards, path.color)
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
    drew_count = refill_hand(hand, 1)

    save
    { success: true, path: path, drew_cards: drew_count }
  end

  def select_cards_to_discard(hand, card_index, start_cost)
    cards_to_discard = [card_index]
    start_cost.times do
      available_indices = (0...hand.length).to_a.reject { |i| cards_to_discard.include?(i) }
      cards_to_discard << available_indices.sample
    end
    cards_to_discard
  end

  def refill_hand(hand, count)
    drew_count = 0
    count.times do
      drawn = draw_card
      if drawn
        hand << drawn
        drew_count += 1
      end
    end
    drew_count
  end
end
