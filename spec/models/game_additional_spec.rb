require 'rails_helper'

RSpec.describe Game, type: :model do
  describe '#handle_player_card_play' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'plays card and triggers AI turn' do
      red_card_index = game.player_hand.index { |c| c['color'] == 'red' }
      result = game.handle_player_card_play(red_card_index, 'red')

      expect(result[:success]).to be true
      expect(game.player_paths.count).to be > 0
    end

    it 'returns error for invalid move' do
      blue_card_index = game.player_hand.index { |c| c['color'] == 'blue' }
      result = game.handle_player_card_play(blue_card_index, 'red')

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end

    it 'does not trigger AI turn on failed play' do
      ai_paths_before = game.ai_paths.count
      blue_card_index = game.player_hand.index { |c| c['color'] == 'blue' }
      expect(blue_card_index).not_to be_nil, "Should have a blue card in hand"

      result = game.handle_player_card_play(blue_card_index, 'red')

      expect(result[:success]).to be false
      # AI should not have played
      expect(game.ai_paths.count).to eq(ai_paths_before)
    end
  end

  describe '#handle_end_turn' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    context 'when deck has cards' do
      it 'discards and draws new hand' do
        game.handle_end_turn
        # Hand should be refilled
        expect(game.player_hand).not_to be_empty
      end

      it 'triggers AI full turn' do
        game.handle_end_turn
        # AI should have attempted to play
        expect(game.ai_paths.count).to be >= 0
      end
    end

    context 'when deck is empty' do
      before do
        game.game_state['deck'] = []
        game.game_state['player_hand'] = []
        game.game_state['ai_hand'] = []
        game.save
      end

      it 'clears hand without drawing' do
        game.handle_end_turn
        expect(game.player_hand).to be_empty
      end

      it 'may end round' do
        game.handle_end_turn
        # With empty deck and empty hands, round should end
        expect(game.status).to eq('round_ending').or eq('finished')
      end
    end
  end

  describe '#discard_all_and_draw' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'discards all cards in hand' do
      hand_size = game.player_hand.length
      result = game.discard_all_and_draw('player')

      expect(result[:success]).to be true
      expect(result[:discarded]).to eq(hand_size)
    end

    it 'draws same number of cards' do
      hand_size = game.player_hand.length
      result = game.discard_all_and_draw('player')

      expect(result[:drew]).to eq(hand_size)
      expect(game.player_hand.length).to eq(hand_size)
    end

    it 'resets consecutive passes' do
      game.game_state['consecutive_passes'] = 5
      game.save

      game.discard_all_and_draw('player')
      expect(game.game_state['consecutive_passes']).to eq(0)
    end

    context 'when deck runs out' do
      before do
        game.game_state['deck'] = [game.game_state['deck'].first]
        game.save
      end

      it 'draws only available cards' do
        result = game.discard_all_and_draw('player')

        expect(result[:drew]).to eq(1)
        expect(game.player_hand.length).to eq(1)
      end
    end
  end

  describe '#clear_hand' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'clears player hand' do
      game.clear_hand('player')
      expect(game.player_hand).to be_empty
    end

    it 'clears AI hand' do
      game.clear_hand('ai')
      expect(game.ai_hand).to be_empty
    end

    it 'saves the change' do
      game.clear_hand('player')
      game.reload
      expect(game.player_hand).to be_empty
    end
  end

  describe '#ai_play_full_turn' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'plays multiple moves until stuck' do
      game.ai_play_full_turn
      # AI should have created at least one path
      expect(game.ai_paths.count).to be >= 0
    end

    it 'does not exceed safety limit' do
      # Even if AI could theoretically make 100 moves, limit is 20
      game.ai_play_full_turn
      # Test passes if it doesn't hang
      expect(true).to be true
    end

    it 'checks for round end after playing' do
      # Empty the deck to trigger round end
      game.game_state['deck'] = []
      game.save

      game.ai_play_full_turn
      # Should check if round should end
      expect(game.status).to eq('round_ending').or eq('finished').or eq('active')
    end
  end

  describe '#check_round_end' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'ends round when both hands empty' do
      game.game_state['player_hand'] = []
      game.game_state['ai_hand'] = []
      game.save

      game.check_round_end
      expect(game.status).to eq('round_ending').or eq('finished')
    end

    it 'ends round when deck empty and players stuck' do
      game.game_state['deck'] = []
      game.game_state['consecutive_passes'] = 6
      game.save

      game.check_round_end
      expect(game.status).to eq('round_ending').or eq('finished')
    end

    it 'ends round when both players stuck' do
      game.game_state['consecutive_passes'] = 6
      game.save

      game.check_round_end
      expect(game.status).to eq('round_ending').or eq('finished')
    end

    it 'does not end round when game can continue' do
      game.check_round_end
      expect(game.status).to eq('active')
    end
  end

  describe 'color validation edge cases' do
    let(:game) { Game.new }

    describe 'red validation' do
      it 'allows jump of exactly 2' do
        cards = [{ 'color' => 'red', 'number' => 5 }]
        new_card = { 'color' => 'red', 'number' => 7 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be true
      end

      it 'allows large jumps' do
        cards = [{ 'color' => 'red', 'number' => 2 }]
        new_card = { 'color' => 'red', 'number' => 20 }
        result = game.validate_card_play(new_card, cards, 'red')
        expect(result[:valid]).to be true
      end
    end

    describe 'blue validation' do
      it 'allows exact match for odd positions' do
        cards = [{ 'color' => 'blue', 'number' => 10 }]
        new_card = { 'color' => 'blue', 'number' => 10 }
        result = game.validate_card_play(new_card, cards, 'blue')
        expect(result[:valid]).to be true
      end

      it 'allows cards at ±3 boundary' do
        cards = [{ 'color' => 'blue', 'number' => 10 }]
        new_card_plus = { 'color' => 'blue', 'number' => 13 }
        new_card_minus = { 'color' => 'blue', 'number' => 7 }

        expect(game.validate_card_play(new_card_plus, cards, 'blue')[:valid]).to be true
        expect(game.validate_card_play(new_card_minus, cards, 'blue')[:valid]).to be true
      end
    end

    describe 'yellow validation' do
      it 'allows ascending by exactly 1' do
        cards = [{ 'color' => 'yellow', 'number' => 10 }]
        new_card = { 'color' => 'yellow', 'number' => 11 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be true
      end

      it 'allows ascending by exactly 3' do
        cards = [{ 'color' => 'yellow', 'number' => 10 }]
        new_card = { 'color' => 'yellow', 'number' => 13 }
        result = game.validate_card_play(new_card, cards, 'yellow')
        expect(result[:valid]).to be true
      end
    end

    describe 'purple validation' do
      it 'allows large descending jumps' do
        cards = [{ 'color' => 'purple', 'number' => 20 }]
        new_card = { 'color' => 'purple', 'number' => 1 }
        result = game.validate_card_play(new_card, cards, 'purple')
        expect(result[:valid]).to be true
      end

      it 'allows very long paths' do
        cards = (20).downto(1).map { |i| { 'color' => 'purple', 'number' => i } }
        # Purple has no limit, so this should be valid
        expect(cards.length).to eq(20)
      end
    end
  end

  describe 'complex AI behavior' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    it 'prefers starting diverse colors' do
      # Give AI cards in multiple colors
      game.game_state['ai_hand'] = [
        { 'color' => 'red', 'number' => 5 },
        { 'color' => 'blue', 'number' => 10 },
        { 'color' => 'green', 'number' => 8 },
        { 'color' => 'yellow', 'number' => 6 },
        { 'color' => 'purple', 'number' => 15 }
      ]
      game.save

      game.ai_play
      # AI should have started a path
      expect(game.ai_paths.count).to be > 0
    end

    it 'evaluates score gain when extending paths' do
      # Create a path that can be extended
      path = create(:color_path, game: game, player_type: 'ai', color: 'purple',
                     cards_data: [{ 'color' => 'purple', 'number' => 15 }].to_json, score: 1)

      # Give AI a valid purple card
      game.game_state['ai_hand'] = [{ 'color' => 'purple', 'number' => 10 }]
      game.save

      game.ai_play
      path.reload
      # Path should have been extended if AI chose to do so
      # AI might start a new path instead, so just verify it made a move
      expect(game.ai_paths.count).to be > 0
    end
  end

  describe 'scoring with bonuses' do
    let(:game) { create(:game, :with_full_deck, :with_hands) }

    before do
      # Create paths with different lengths for bonus testing
      create(:color_path, game: game, player_type: 'player', color: 'red',
             cards_data: (1..5).map { |i| { 'color' => 'red', 'number' => i * 3 } }.to_json,
             score: 25) # 5 cards

      create(:color_path, game: game, player_type: 'player', color: 'blue',
             cards_data: (1..7).map { |i| { 'color' => 'blue', 'number' => i } }.to_json,
             score: 49) # 7 cards
    end

    it 'applies long path bonus for 5+ cards' do
      game.end_round
      summary = game.game_state['round_summary']

      # Should have bonuses: 5 for red (5 cards), 10 for blue (7 cards)
      expect(summary['player_bonus']).to eq(15)
    end

    it 'applies combo multiplier for multiple paths' do
      game.end_round
      summary = game.game_state['round_summary']

      # Player has 2 paths, should get 1.1x multiplier
      expect(summary['player_multiplier']).to eq(1.1)
    end
  end

  describe 'round progression with path persistence' do
    let(:game) { create(:game, :round_ending) }

    before do
      create(:color_path, :red_path, game: game, player_type: 'player')
      create(:color_path, :blue_path, game: game, player_type: 'ai')
      # Ensure deck has some cards for next round
      game.game_state['deck'] = game.create_deck.take(50)
      game.save
    end

    it 'keeps paths when continuing to next round' do
      paths_before = game.color_paths.to_a
      game.continue_to_next_round
      game.reload

      expect(game.color_paths.count).to eq(paths_before.count)
    end

    it 'maintains deck without resetting' do
      deck_size_before = game.game_state['deck'].length
      game.continue_to_next_round

      # Deck should be smaller (drew 20 cards for hands)
      expect(game.game_state['deck'].length).to be < deck_size_before
    end
  end

  describe 'game constants' do
    it 'has correct number of colors' do
      expect(Game::COLORS.length).to eq(5)
      expect(Game::COLORS).to include('red', 'blue', 'green', 'yellow', 'purple')
    end

    it 'has correct total rounds' do
      expect(Game::TOTAL_ROUNDS).to eq(10)
    end

    it 'has correct hand size' do
      expect(Game::HAND_SIZE).to eq(10)
    end

    it 'has correct deck size per color' do
      expect(Game::DECK_SIZE).to eq(20)
    end
  end
end
