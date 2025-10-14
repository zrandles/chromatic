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

    case color
    when 'red'
      # Must ascend with jumps of 2+, max 8 cards
      if card_array.length >= 8
        "COMPLETE (8 cards max)"
      else
        "Next: #{last_number + 2}+ (jump by 2+, #{8 - card_array.length} left)"
      end
    when 'blue'
      # Pairs with flexibility
      if card_array.length >= 10
        "COMPLETE (10 cards max)"
      elsif card_array.length.odd?
        "Next: #{last_number} (pair) OR #{last_number - 1}/#{last_number + 1} (extend)"
      else
        prev_pair = card_array.length >= 2 ? card_array[-2]['number'] : nil
        if prev_pair
          "Next: Any except #{prev_pair} (#{10 - card_array.length} left)"
        else
          "Next: Any number (#{10 - card_array.length} left)"
        end
      end
    when 'green'
      # Consecutive but max 6
      if card_array.length >= 6
        "COMPLETE (6 cards max)"
      else
        "Next: #{last_number - 1} or #{last_number + 1} (#{6 - card_array.length} left)"
      end
    when 'yellow'
      # Ascending by 1s (1,2,3,4...)
      if card_array.length >= 8
        "COMPLETE (8 cards max)"
      else
        "Next: #{last_number + 1} only (#{8 - card_array.length} left)"
      end
    when 'purple'
      # Any descending (no cap)
      "Next: 1-#{last_number - 1} (any lower number, no cap!)"
    end
  end
end
