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
end
