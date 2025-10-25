FactoryBot.define do
  factory :game do
    status { 'active' }
    current_round { 1 }
    total_rounds { 10 }
    player_score { 0 }
    ai_score { 0 }
    game_state do
      {
        'deck' => [],
        'player_hand' => [],
        'ai_hand' => [],
        'turn' => 'player'
      }
    end

    # Default factory creates a new game with full setup
    after(:build) do |game|
      # Let the model's after_initialize callback handle setup
      # This ensures we're testing the actual game initialization logic
    end

    trait :with_full_deck do
      after(:create) do |game|
        # Create a fresh game with full deck (100 cards)
        game.game_state['deck'] = game.create_deck
        game.save
      end
    end

    trait :with_hands do
      after(:create) do |game|
        # Deal hands to both players
        game.game_state['player_hand'] = game.draw_hand
        game.game_state['ai_hand'] = game.draw_hand
        game.save
      end
    end

    trait :finished do
      status { 'finished' }
      current_round { 10 }
      player_score { 150 }
      ai_score { 120 }
    end

    trait :round_ending do
      status { 'round_ending' }
      after(:create) do |game|
        game.game_state['round_summary'] = {
          'round' => game.current_round,
          'player_round_score' => 25,
          'ai_round_score' => 20,
          'player_base_score' => 25,
          'ai_base_score' => 20,
          'player_bonus' => 0,
          'ai_bonus' => 0,
          'player_multiplier' => 1.0,
          'ai_multiplier' => 1.0,
          'player_path_count' => 2,
          'ai_path_count' => 2,
          'player_total_before' => game.player_score,
          'ai_total_before' => game.ai_score
        }
        game.save
      end
    end

    # Factory for testing specific game states
    trait :mid_game do
      current_round { 5 }
      player_score { 50 }
      ai_score { 45 }
      after(:create) do |game|
        # Create some color paths for both players
        create(:color_path, game: game, color: 'red', player_type: 'player', cards_data: [
          { 'color' => 'red', 'number' => 5 },
          { 'color' => 'red', 'number' => 8 },
          { 'color' => 'red', 'number' => 11 }
        ].to_json, score: 9)

        create(:color_path, game: game, color: 'blue', player_type: 'ai', cards_data: [
          { 'color' => 'blue', 'number' => 10 },
          { 'color' => 'blue', 'number' => 12 }
        ].to_json, score: 4)
      end
    end
  end
end
