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
      # Must ascend with jumps of 2+
      "Next: #{last_number + 2}+ (jump by 2 or more)"
    when 'blue'
      # Pairs only
      if card_array.length.odd?
        "Next: #{last_number} (complete the pair)"
      else
        prev_pair = card_array.length >= 2 ? card_array[-2]['number'] : nil
        if prev_pair
          "Next: Any number except #{prev_pair} (start new pair)"
        else
          "Next: Any number (start new pair)"
        end
      end
    when 'green'
      # Consecutive but max 5
      if card_array.length >= 5
        "COMPLETE (5 cards max)"
      else
        "Next: #{last_number - 1} or #{last_number + 1} (#{5 - card_array.length} left)"
      end
    when 'yellow'
      # Multiples (same number)
      if card_array.length >= 4
        "COMPLETE (4 cards max)"
      else
        "Next: #{last_number} only (#{4 - card_array.length} more copies)"
      end
    when 'purple'
      # Any descending
      "Next: 1-#{last_number - 1} (any lower number)"
    end
  end
end
