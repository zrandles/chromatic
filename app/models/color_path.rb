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
      # Must ascend with jumps (no consecutive)
      "Next: #{last_number + 2}-20 (no #{last_number + 1})"
    when 'blue'
      # Waves (alternating up/down)
      if card_array.length >= 2
        last_direction = card_array[-1]['number'] > card_array[-2]['number'] ? 'up' : 'down'
        if last_direction == 'up'
          "Next: Must go down (1-#{last_number - 1})"
        else
          "Next: Must go up (#{last_number + 1}-20)"
        end
      else
        "Next: Any number (will start wave pattern)"
      end
    when 'green'
      # Consecutive numbers only
      "Next: #{last_number - 1} or #{last_number + 1} only"
    when 'yellow'
      # Solo cards - only one card per path
      "COMPLETE (Yellow = 1 card max)"
    when 'purple'
      # Descends exponentially
      max_next = (last_number * 0.7).floor
      "Next: 1-#{max_next} (≤70% of #{last_number})"
    end
  end
end
