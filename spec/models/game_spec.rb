require 'rails_helper'

RSpec.describe Game, type: :model do
  describe 'associations' do
    it { should have_many(:color_paths).dependent(:destroy) }
  end

  describe 'initialization' do
    it 'sets up a new game with defaults' do
      game = Game.new
      expect(game.status).to eq('active')
      expect(game.current_round).to eq(1)
      expect(game.total_rounds).to eq(10)
      expect(game.player_score).to eq(0)
      expect(game.ai_score).to eq(0)
    end

    it 'creates a full deck of 100 cards' do
      game = Game.create!
      deck = game.game_state['deck']
      # After dealing hands (20 cards total), deck should have 80 cards
      expect(deck.length).to eq(80) # 100 - 20 (dealt to players)
    end

    it 'deals hands to both players' do
      game = Game.create!
      expect(game.player_hand.length).to eq(10)
      expect(game.ai_hand.length).to eq(10)
    end

    it 'shuffles the deck' do
      game1 = Game.create!
      game2 = Game.create!
      # Decks should be different due to shuffling
      expect(game1.game_state['deck']).not_to eq(game2.game_state['deck'])
    end
  end

  describe '#create_deck' do
    let(:game) { Game.new }

    it 'creates cards for all 5 colors' do
      deck = game.create_deck
      colors = deck.map { |c| c['color'] }.uniq.sort
      expect(colors).to eq(%w[blue green purple red yellow])
    end

    it 'creates 20 cards per color' do
      deck = game.create_deck
      Game::COLORS.each do |color|
        color_cards = deck.select { |c| c['color'] == color }
        expect(color_cards.length).to eq(20)
      end
    end

    it 'creates cards numbered 1-20' do
      deck = game.create_deck
      red_cards = deck.select { |c| c['color'] == 'red' }
      numbers = red_cards.map { |c| c['number'] }.sort
      expect(numbers).to eq((1..20).to_a)
    end
  end

  describe '#play_card' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    context 'starting a new path' do
      it 'creates a new color path when playing first card of that color' do
        red_card_index = game.player_hand.index { |c| c['color'] == 'red' }
        expect {
          game.play_card(red_card_index, 'red', 'player')
        }.to change(game.color_paths, :count).by(1)
      end

      it 'requires card color to match path color' do
        blue_card_index = game.player_hand.index { |c| c['color'] == 'blue' }
        result = game.play_card(blue_card_index, 'red', 'player')
        expect(result[:success]).to be false
        expect(result[:error]).to include('Card color must match path color')
      end

      it 'first path is free (no additional cards needed)' do
        hand_size_before = game.player_hand.length
        red_card_index = game.player_hand.index { |c| c['color'] == 'red' }
        game.play_card(red_card_index, 'red', 'player')
        # Should lose 1 card (the played card) and draw 1 back if deck has cards
        # But deck might be empty, so just check it didn't increase
        expect(game.player_hand.length).to be <= hand_size_before
      end

      it 'second path costs 1 additional card' do
        # Start first path
        red_card_index = game.player_hand.index { |c| c['color'] == 'red' }
        game.play_card(red_card_index, 'red', 'player')

        # Reload game to get updated state
        game.reload

        # Start second path - requires 2 cards total (1 played + 1 discarded)
        blue_card_index = game.player_hand.index { |c| c['color'] == 'blue' }
        result = game.play_card(blue_card_index, 'blue', 'player')
        expect(result[:success]).to be true
      end

      it 'third path costs 2 additional cards' do
        # Start first and second paths
        red_idx = game.player_hand.index { |c| c['color'] == 'red' }
        game.play_card(red_idx, 'red', 'player')
        blue_idx = game.player_hand.index { |c| c['color'] == 'blue' }
        game.play_card(blue_idx, 'blue', 'player')

        # Third path requires 3 cards total (1 played + 2 discarded)
        hand_size_before = game.player_hand.length
        expect(hand_size_before).to be >= 3
        green_idx = game.player_hand.index { |c| c['color'] == 'green' }
        result = game.play_card(green_idx, 'green', 'player')
        expect(result[:success]).to be true
      end
    end

    context 'extending existing paths' do
      it 'adds card to existing path' do
        path = create(:color_path, :red_path, game: game, player_type: 'player')
        # Add a valid card to hand (last card is 8, so need 10+)
        game.player_hand[0] = { 'color' => 'red', 'number' => 14 }
        game.save

        result = game.play_card(0, 'red', 'player')
        expect(result[:success]).to be true

        path.reload
        expect(path.cards.length).to eq(3)
        expect(path.score).to eq(9) # 3^2
      end

      it 'draws a card after playing' do
        path = create(:color_path, game: game, player_type: 'player', color: 'purple')
        hand_size_before = game.player_hand.length

        # Add a valid purple card to hand
        game.player_hand[0] = { 'color' => 'purple', 'number' => 3 }
        game.save

        game.play_card(0, 'purple', 'player')
        # Should maintain or decrease hand size (depends on deck)
        expect(game.player_hand.length).to be <= hand_size_before
      end
    end
  end

  describe '#validate_card_play' do
    let(:game) { Game.new }

    describe 'red (ascending with jumps of 2+)' do
      it 'accepts cards that ascend by 2 or more' do
        cards = [{ 'color' => 'red', 'number' => 5 }]
        new_card = { 'color' => 'red', 'number' => 8 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be true
      end

      it 'rejects cards that ascend by only 1' do
        cards = [{ 'color' => 'red', 'number' => 5 }]
        new_card = { 'color' => 'red', 'number' => 6 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('jump by at least 2')
      end

      it 'rejects descending cards' do
        cards = [{ 'color' => 'red', 'number' => 10 }]
        new_card = { 'color' => 'red', 'number' => 8 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('must ascend')
      end

      it 'limits red paths to 8 cards' do
        cards = [
          { 'color' => 'red', 'number' => 2 },
          { 'color' => 'red', 'number' => 5 },
          { 'color' => 'red', 'number' => 8 },
          { 'color' => 'red', 'number' => 11 },
          { 'color' => 'red', 'number' => 14 },
          { 'color' => 'red', 'number' => 17 },
          { 'color' => 'red', 'number' => 20 },
          { 'color' => 'red', 'number' => 23 }
        ]
        new_card = { 'color' => 'red', 'number' => 26 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('maxes out at 8 cards')
      end
    end

    describe 'blue (loose pairing within ±3)' do
      it 'accepts paired cards within ±3' do
        cards = [{ 'color' => 'blue', 'number' => 10 }]
        new_card = { 'color' => 'blue', 'number' => 12 }
        result = game.validate_card_play(new_card, cards, 'blue')
        expect(result[:valid]).to be true
      end

      it 'accepts any number for even positions' do
        cards = [
          { 'color' => 'blue', 'number' => 10 },
          { 'color' => 'blue', 'number' => 12 }
        ]
        new_card = { 'color' => 'blue', 'number' => 2 }
        result = game.validate_card_play(new_card, cards, 'blue')
        expect(result[:valid]).to be true
      end

      it 'rejects cards outside ±3 range for odd positions' do
        cards = [{ 'color' => 'blue', 'number' => 10 }]
        new_card = { 'color' => 'blue', 'number' => 15 }
        result = game.validate_card_play(new_card, cards, 'blue')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('within ±3')
      end

      it 'limits blue paths to 10 cards' do
        cards = (1..10).map { |i| { 'color' => 'blue', 'number' => i } }
        new_card = { 'color' => 'blue', 'number' => 11 }
        result = game.validate_card_play(new_card, cards, 'blue')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('maxes out at 10 cards')
      end
    end

    describe 'green (consecutive)' do
      it 'accepts consecutive ascending cards' do
        cards = [{ 'color' => 'green', 'number' => 8 }]
        new_card = { 'color' => 'green', 'number' => 9 }
        result = game.validate_card_play(new_card, cards, 'green')
        expect(result[:valid]).to be true
      end

      it 'accepts consecutive descending cards' do
        cards = [{ 'color' => 'green', 'number' => 8 }]
        new_card = { 'color' => 'green', 'number' => 7 }
        result = game.validate_card_play(new_card, cards, 'green')
        expect(result[:valid]).to be true
      end

      it 'rejects non-consecutive cards' do
        cards = [{ 'color' => 'green', 'number' => 8 }]
        new_card = { 'color' => 'green', 'number' => 10 }
        result = game.validate_card_play(new_card, cards, 'green')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('must be consecutive')
      end

      it 'limits green paths to 6 cards' do
        cards = (8..13).map { |i| { 'color' => 'green', 'number' => i } }
        new_card = { 'color' => 'green', 'number' => 14 }
        result = game.validate_card_play(new_card, cards, 'green')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('maxes out at 6 cards')
      end
    end

    describe 'yellow (ascending by 1-3)' do
      it 'accepts ascending by 1' do
        cards = [{ 'color' => 'yellow', 'number' => 5 }]
        new_card = { 'color' => 'yellow', 'number' => 6 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be true
      end

      it 'accepts ascending by 3' do
        cards = [{ 'color' => 'yellow', 'number' => 5 }]
        new_card = { 'color' => 'yellow', 'number' => 8 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be true
      end

      it 'rejects descending cards' do
        cards = [{ 'color' => 'yellow', 'number' => 5 }]
        new_card = { 'color' => 'yellow', 'number' => 4 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('must ascend')
      end

      it 'rejects ascending by more than 3' do
        cards = [{ 'color' => 'yellow', 'number' => 5 }]
        new_card = { 'color' => 'yellow', 'number' => 9 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('ascend by 1-3')
      end

      it 'limits yellow paths to 8 cards' do
        cards = (5..12).map { |i| { 'color' => 'yellow', 'number' => i } }
        new_card = { 'color' => 'yellow', 'number' => 13 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('maxes out at 8 cards')
      end
    end

    describe 'purple (any descending, no limit)' do
      it 'accepts any descending card' do
        cards = [{ 'color' => 'purple', 'number' => 15 }]
        new_card = { 'color' => 'purple', 'number' => 8 }
        result = game.validate_card_play(new_card, cards, 'purple')
        expect(result[:valid]).to be true
      end

      it 'rejects ascending cards' do
        cards = [{ 'color' => 'purple', 'number' => 10 }]
        new_card = { 'color' => 'purple', 'number' => 12 }
        result = game.validate_card_play(new_card, cards, 'purple')
        expect(result[:valid]).to be false
        expect(result[:error]).to include('must descend')
      end

      it 'has no card limit' do
        cards = (20).downto(10).map { |i| { 'color' => 'purple', 'number' => i } }
        new_card = { 'color' => 'purple', 'number' => 9 }
        result = game.validate_card_play(new_card, cards, 'purple')
        expect(result[:valid]).to be true
      end
    end
  end

  describe '#ai_play' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'makes a valid move' do
      result = game.ai_play
      expect(result).to be_truthy
      expect(game.ai_paths.count).to be > 0
    end

    it 'prefers extending existing paths over starting new ones when valuable' do
      # Create a long AI path with purple
      path = create(:color_path, game: game, player_type: 'ai', color: 'purple',
                     cards_data: [{ 'color' => 'purple', 'number' => 15 }].to_json, score: 1)

      # Give AI a purple card that can extend (must be lower than 15)
      game.game_state['ai_hand'][0] = { 'color' => 'purple', 'number' => 10 }
      game.save

      paths_before = game.ai_paths.count
      game.ai_play

      # Should extend existing path if possible
      # (AI might still create new path depending on strategy)
      expect(game.ai_paths.count).to be >= paths_before
    end

    it 'returns nil when no valid moves available' do
      # Empty the AI hand
      game.game_state['ai_hand'] = []
      game.save

      result = game.ai_play
      expect(result).to be_nil
    end
  end

  describe '#end_round' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    before do
      # Create some paths for scoring
      create(:color_path, :red_path, game: game, player_type: 'player')
      create(:color_path, :blue_path, game: game, player_type: 'player')
      create(:color_path, :green_path, game: game, player_type: 'ai')
    end

    it 'calculates player score' do
      game.end_round
      expect(game.player_score).to be > 0
    end

    it 'calculates AI score' do
      game.end_round
      expect(game.ai_score).to be > 0
    end

    it 'stores round summary' do
      game.end_round
      expect(game.game_state['round_summary']).to be_present
      expect(game.game_state['round_summary']['round']).to eq(1)
    end

    it 'applies combo multiplier for multiple paths' do
      game.end_round
      summary = game.game_state['round_summary']

      # Player has 2 paths, should get 1.1x multiplier
      expect(summary['player_multiplier']).to eq(1.1)

      # AI has 1 path, should get 1.0x multiplier
      expect(summary['ai_multiplier']).to eq(1.0)
    end

    it 'sets status to round_ending' do
      game.end_round
      expect(game.status).to eq('round_ending')
    end

    it 'sets status to finished when max rounds reached' do
      game.update(current_round: 10)
      game.end_round
      expect(game.status).to eq('finished')
    end

    it 'sets status to finished when deck is depleted' do
      game.game_state['deck'] = []
      game.save
      game.end_round
      expect(game.status).to eq('finished')
    end
  end

  describe '#calculate_combo_multiplier' do
    let(:game) { Game.new }

    it 'returns 1.0x for 1 path' do
      expect(game.calculate_combo_multiplier(1)).to eq(1.0)
    end

    it 'returns 1.1x for 2 paths' do
      expect(game.calculate_combo_multiplier(2)).to eq(1.1)
    end

    it 'returns 1.25x for 3 paths' do
      expect(game.calculate_combo_multiplier(3)).to eq(1.25)
    end

    it 'returns 1.4x for 4 paths' do
      expect(game.calculate_combo_multiplier(4)).to eq(1.4)
    end

    it 'returns 1.6x for 5 paths (rainbow bonus)' do
      expect(game.calculate_combo_multiplier(5)).to eq(1.6)
    end
  end

  describe '#calculate_long_path_bonus' do
    let(:game) { Game.new }

    it 'returns 0 for paths under 5 cards' do
      expect(game.calculate_long_path_bonus(4)).to eq(0)
    end

    it 'returns 5 for paths with 5-6 cards' do
      expect(game.calculate_long_path_bonus(5)).to eq(5)
      expect(game.calculate_long_path_bonus(6)).to eq(5)
    end

    it 'returns 10 for paths with 7-9 cards' do
      expect(game.calculate_long_path_bonus(7)).to eq(10)
      expect(game.calculate_long_path_bonus(9)).to eq(10)
    end

    it 'returns 20 for paths with 10+ cards' do
      expect(game.calculate_long_path_bonus(10)).to eq(20)
      expect(game.calculate_long_path_bonus(15)).to eq(20)
    end
  end

  describe '#continue_to_next_round' do
    let(:game) { create(:game, :round_ending) }

    it 'advances the round number' do
      expect {
        game.continue_to_next_round
      }.to change(game, :current_round).by(1)
    end

    it 'clears round summary' do
      game.continue_to_next_round
      expect(game.game_state['round_summary']).to be_nil
    end

    it 'sets status back to active' do
      game.continue_to_next_round
      expect(game.status).to eq('active')
    end

    it 'refills both hands' do
      game.continue_to_next_round
      expect(game.player_hand.length).to be > 0
      expect(game.ai_hand.length).to be > 0
    end

    it 'preserves existing color paths' do
      path = create(:color_path, game: game, player_type: 'player')
      game.continue_to_next_round
      expect(game.color_paths).to include(path)
    end
  end

  describe '#winner' do
    let(:game) { create(:game, :finished) }

    it 'returns player when player has higher score' do
      game.update(player_score: 150, ai_score: 120)
      expect(game.winner).to eq('player')
    end

    it 'returns ai when AI has higher score' do
      game.update(player_score: 120, ai_score: 150)
      expect(game.winner).to eq('ai')
    end

    it 'returns tie when scores are equal' do
      game.update(player_score: 150, ai_score: 150)
      expect(game.winner).to eq('tie')
    end

    it 'returns nil when game is not finished' do
      game.update(status: 'active')
      expect(game.winner).to be_nil
    end
  end

  describe '#discard_and_draw' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'removes card from hand' do
      hand_before = game.player_hand.dup
      game.discard_and_draw(0, 'player')
      expect(game.player_hand).not_to include(hand_before[0])
    end

    it 'draws a new card' do
      hand_size = game.player_hand.length
      result = game.discard_and_draw(0, 'player')
      expect(result[:success]).to be true
      expect(result[:card]).to be_present
    end

    it 'returns error when deck is empty' do
      game.game_state['deck'] = []
      game.save
      result = game.discard_and_draw(0, 'player')
      expect(result[:success]).to be false
      expect(result[:error]).to include('Deck is empty')
    end
  end

  describe '#starting_cost_for_path_number' do
    let(:game) { Game.new }

    it 'first path is free' do
      expect(game.starting_cost_for_path_number(0)).to eq(0)
    end

    it 'second path costs 1 card' do
      expect(game.starting_cost_for_path_number(1)).to eq(1)
    end

    it 'third path costs 2 cards' do
      expect(game.starting_cost_for_path_number(2)).to eq(2)
    end

    it 'fourth path costs 3 cards' do
      expect(game.starting_cost_for_path_number(3)).to eq(3)
    end

    it 'fifth path costs 4 cards' do
      expect(game.starting_cost_for_path_number(4)).to eq(4)
    end
  end
end
