# Card validation logic for color-specific rules
module CardValidation
  extend ActiveSupport::Concern

  def validate_card_play(card, existing_cards, color)
    return { valid: false, error: 'Wrong color' } unless card['color'] == color

    numbers = existing_cards.map { |c| c['number'] }
    new_number = card['number']

    case color
    when 'red'
      validate_red_card(new_number, numbers)
    when 'blue'
      validate_blue_card(new_number, numbers)
    when 'green'
      validate_green_card(new_number, numbers)
    when 'yellow'
      validate_yellow_card(new_number, numbers)
    when 'purple'
      validate_purple_card(new_number, numbers)
    else
      { valid: false, error: 'Unknown color' }
    end
  end

  private

  # Red: Must ascend with jumps of 2+ (max 8 cards)
  def validate_red_card(new_number, numbers)
    last_number = numbers.last
    return { valid: false, error: 'Red maxes out at 8 cards' } if numbers.length >= 8
    return { valid: false, error: 'Red must ascend' } unless new_number > last_number
    return { valid: false, error: 'Red must jump by at least 2' } if new_number - last_number < 2
    { valid: true }
  end

  # Blue: Loose pairing - every 2nd card must be within ±3 (max 10 cards)
  def validate_blue_card(new_number, numbers)
    last_number = numbers.last
    return { valid: false, error: 'Blue maxes out at 10 cards' } if numbers.length >= 10

    # Odd card: Must be within ±3 of last card (pairing mechanic)
    if numbers.length.odd?
      distance = (new_number - last_number).abs
      return { valid: false, error: 'Blue must be within ±3 of previous card (loose pairing)' } unless distance <= 3
    end
    # Even card: Can be any number (starting new "pair")

    { valid: true }
  end

  # Green: Consecutive (±1), max 6 cards
  def validate_green_card(new_number, numbers)
    last_number = numbers.last
    return { valid: false, error: 'Green maxes out at 6 cards' } if numbers.length >= 6
    return { valid: false, error: 'Green must be consecutive' } unless (new_number - last_number).abs == 1
    { valid: true }
  end

  # Yellow: Must ascend by 1-3 (max 8 cards)
  def validate_yellow_card(new_number, numbers)
    return { valid: false, error: 'Yellow maxes out at 8 cards' } if numbers.length >= 8

    if numbers.any?
      last_number = numbers.last
      jump = new_number - last_number
      return { valid: false, error: 'Yellow must ascend' } unless jump > 0
      return { valid: false, error: 'Yellow must ascend by 1-3' } unless jump >= 1 && jump <= 3
    end

    { valid: true }
  end

  # Purple: Descending by any amount (no cap)
  def validate_purple_card(new_number, numbers)
    last_number = numbers.last
    return { valid: false, error: 'Purple must descend' } unless new_number < last_number
    { valid: true }
  end
end
