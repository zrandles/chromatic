FactoryBot.define do
  factory :color_path do
    association :game
    color { 'red' }
    player_type { 'player' }
    score { 1 }
    cards_data do
      [{ 'color' => color, 'number' => 5 }].to_json
    end

    # Trait for each color with appropriate starting cards
    trait :red_path do
      color { 'red' }
      cards_data do
        [
          { 'color' => 'red', 'number' => 5 },
          { 'color' => 'red', 'number' => 8 }
        ].to_json
      end
      score { 4 }
    end

    trait :blue_path do
      color { 'blue' }
      cards_data do
        [
          { 'color' => 'blue', 'number' => 10 },
          { 'color' => 'blue', 'number' => 12 }
        ].to_json
      end
      score { 4 }
    end

    trait :green_path do
      color { 'green' }
      cards_data do
        [
          { 'color' => 'green', 'number' => 8 },
          { 'color' => 'green', 'number' => 9 },
          { 'color' => 'green', 'number' => 10 }
        ].to_json
      end
      score { 9 }
    end

    trait :yellow_path do
      color { 'yellow' }
      cards_data do
        [
          { 'color' => 'yellow', 'number' => 5 },
          { 'color' => 'yellow', 'number' => 7 }
        ].to_json
      end
      score { 4 }
    end

    trait :purple_path do
      color { 'purple' }
      cards_data do
        [
          { 'color' => 'purple', 'number' => 15 },
          { 'color' => 'purple', 'number' => 12 },
          { 'color' => 'purple', 'number' => 8 }
        ].to_json
      end
      score { 9 }
    end

    trait :ai_path do
      player_type { 'ai' }
    end

    trait :long_path do
      cards_data do
        [
          { 'color' => 'purple', 'number' => 20 },
          { 'color' => 'purple', 'number' => 18 },
          { 'color' => 'purple', 'number' => 16 },
          { 'color' => 'purple', 'number' => 14 },
          { 'color' => 'purple', 'number' => 12 },
          { 'color' => 'purple', 'number' => 10 }
        ].to_json
      end
      score { 36 }
    end

    trait :complete_red do
      color { 'red' }
      cards_data do
        [
          { 'color' => 'red', 'number' => 2 },
          { 'color' => 'red', 'number' => 5 },
          { 'color' => 'red', 'number' => 8 },
          { 'color' => 'red', 'number' => 11 },
          { 'color' => 'red', 'number' => 14 },
          { 'color' => 'red', 'number' => 17 },
          { 'color' => 'red', 'number' => 20 },
          { 'color' => 'red', 'number' => 22 }  # Max 8 cards
        ].to_json
      end
      score { 64 }
    end
  end
end
