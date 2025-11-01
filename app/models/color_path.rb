# ColorPath model - represents a player's color-specific card sequence
class ColorPath < ApplicationRecord
  belongs_to :game

  def cards
    JSON.parse(cards_data)
  end

  def add_card(card)
    cards_array = cards
    cards_array << card
    self.cards_data = cards_array.to_json
    self.score = cards_array.length ** 2
    save
  end

  def next_play_hint
    card_array = cards
    last_number = card_array.last['number']
    cards_remaining = cards_remaining_for_color

    case color
    when 'red'   then red_hint(last_number, card_array.length, cards_remaining)
    when 'blue'  then blue_hint(last_number, card_array.length, cards_remaining)
    when 'green' then green_hint(last_number, card_array.length, cards_remaining)
    when 'yellow' then yellow_hint(last_number, card_array.length, cards_remaining)
    when 'purple' then purple_hint(last_number)
    end
  end

  private

  def cards_remaining_for_color
    max_cards = { 'red' => 8, 'blue' => 10, 'green' => 6, 'yellow' => 8 }
    max_cards[color]
  end

  def red_hint(last_number, length, max_cards)
    return "COMPLETE (#{max_cards} cards max)" if length >= max_cards
    "Next: #{last_number + 2}+ (jump by 2+, #{max_cards - length} left)"
  end

  def blue_hint(last_number, length, max_cards)
    return "COMPLETE (#{max_cards} cards max)" if length >= max_cards

    if length.odd?
      min_val = [last_number - 3, 1].max
      max_val = [last_number + 3, 20].min
      "Next: #{min_val}-#{max_val} (within ±3, #{max_cards - length} left)"
    else
      "Next: Any number (#{max_cards - length} left)"
    end
  end

  def green_hint(last_number, length, max_cards)
    return "COMPLETE (#{max_cards} cards max)" if length >= max_cards
    "Next: #{last_number - 1} or #{last_number + 1} (#{max_cards - length} left)"
  end

  def yellow_hint(last_number, length, max_cards)
    return "COMPLETE (#{max_cards} cards max)" if length >= max_cards
    min_val = last_number + 1
    max_val = [last_number + 3, 20].min
    "Next: #{min_val}-#{max_val} (ascend by 1-3, #{max_cards - length} left)"
  end

  def purple_hint(last_number)
    "Next: 1-#{last_number - 1} (any lower number, no cap!)"
  end
end
