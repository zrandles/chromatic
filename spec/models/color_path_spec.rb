require 'rails_helper'

RSpec.describe ColorPath, type: :model do
  describe 'associations' do
    it { should belong_to(:game) }
  end

  describe '#cards' do
    let(:path) { create(:color_path) }

    it 'parses cards_data JSON into array' do
      expect(path.cards).to be_an(Array)
      expect(path.cards.first).to have_key('color')
      expect(path.cards.first).to have_key('number')
    end
  end

  describe '#add_card' do
    let(:path) { create(:color_path, cards_data: [{ 'color' => 'red', 'number' => 5 }].to_json, score: 1) }

    it 'adds card to the path' do
      new_card = { 'color' => 'red', 'number' => 8 }
      expect {
        path.add_card(new_card)
      }.to change { path.cards.length }.by(1)
    end

    it 'updates the score' do
      new_card = { 'color' => 'red', 'number' => 8 }
      path.add_card(new_card)
      expect(path.score).to eq(4) # 2^2 = 4
    end

    it 'saves the changes' do
      new_card = { 'color' => 'red', 'number' => 8 }
      path.add_card(new_card)
      path.reload
      expect(path.cards.length).to eq(2)
    end
  end

  describe '#next_play_hint' do
    describe 'red paths' do
      it 'shows next valid range for incomplete path' do
        path = create(:color_path, :red_path)
        hint = path.next_play_hint
        expect(hint).to include('10+') # Last card is 8, so next must be 10+
        expect(hint).to include('jump by 2+')
      end

      it 'shows completion message when path has 8 cards' do
        path = create(:color_path, :complete_red)
        hint = path.next_play_hint
        expect(hint).to include('COMPLETE')
        expect(hint).to include('8 cards max')
      end
    end

    describe 'blue paths' do
      it 'shows ±3 range for odd-length paths' do
        path = create(:color_path, :blue_path, cards_data: [{ 'color' => 'blue', 'number' => 10 }].to_json)
        hint = path.next_play_hint
        expect(hint).to include('7-13') # 10 ± 3
        expect(hint).to include('within ±3')
      end

      it 'shows "Any number" for even-length paths' do
        path = create(:color_path, :blue_path)
        hint = path.next_play_hint
        expect(hint).to include('Any number')
      end

      it 'shows completion message when path has 10 cards' do
        cards = (1..10).map { |i| { 'color' => 'blue', 'number' => i } }
        path = create(:color_path, color: 'blue', cards_data: cards.to_json)
        hint = path.next_play_hint
        expect(hint).to include('COMPLETE')
        expect(hint).to include('10 cards max')
      end
    end

    describe 'green paths' do
      it 'shows consecutive options' do
        path = create(:color_path, :green_path, cards_data: [{ 'color' => 'green', 'number' => 8 }].to_json)
        hint = path.next_play_hint
        expect(hint).to include('7 or 9')
      end

      it 'shows completion message when path has 6 cards' do
        cards = (8..13).map { |i| { 'color' => 'green', 'number' => i } }
        path = create(:color_path, color: 'green', cards_data: cards.to_json)
        hint = path.next_play_hint
        expect(hint).to include('COMPLETE')
        expect(hint).to include('6 cards max')
      end
    end

    describe 'yellow paths' do
      it 'shows ascending range of 1-3' do
        path = create(:color_path, :yellow_path, cards_data: [{ 'color' => 'yellow', 'number' => 5 }].to_json)
        hint = path.next_play_hint
        expect(hint).to include('6-8') # 5 + (1 to 3)
        expect(hint).to include('ascend by 1-3')
      end

      it 'respects upper bound of 20' do
        path = create(:color_path, color: 'yellow', cards_data: [{ 'color' => 'yellow', 'number' => 19 }].to_json)
        hint = path.next_play_hint
        expect(hint).to include('20-20') # Can only go to 20
      end

      it 'shows completion message when path has 8 cards' do
        cards = (5..12).map { |i| { 'color' => 'yellow', 'number' => i } }
        path = create(:color_path, color: 'yellow', cards_data: cards.to_json)
        hint = path.next_play_hint
        expect(hint).to include('COMPLETE')
        expect(hint).to include('8 cards max')
      end
    end

    describe 'purple paths' do
      it 'shows any lower number' do
        path = create(:color_path, :purple_path, cards_data: [{ 'color' => 'purple', 'number' => 15 }].to_json)
        hint = path.next_play_hint
        expect(hint).to include('1-14')
        expect(hint).to include('any lower number')
      end

      it 'mentions no cap' do
        path = create(:color_path, :purple_path)
        hint = path.next_play_hint
        expect(hint).to include('no cap')
      end
    end
  end

  describe 'scoring' do
    it 'scores based on number of cards squared' do
      path1 = create(:color_path, cards_data: [{ 'color' => 'red', 'number' => 5 }].to_json)
      expect(path1.score).to eq(1) # 1^2

      path2 = create(:color_path, :red_path) # 2 cards
      expect(path2.score).to eq(4) # 2^2

      path3 = create(:color_path, :green_path) # 3 cards
      expect(path3.score).to eq(9) # 3^2

      path4 = create(:color_path, :long_path) # 6 cards
      expect(path4.score).to eq(36) # 6^2
    end
  end

  describe 'player_type' do
    it 'can be player' do
      path = create(:color_path, player_type: 'player')
      expect(path.player_type).to eq('player')
    end

    it 'can be ai' do
      path = create(:color_path, :ai_path)
      expect(path.player_type).to eq('ai')
    end
  end

  describe 'color paths' do
    it 'supports all 5 colors' do
      game = create(:game)
      Game::COLORS.each do |color|
        path = create(:color_path, game: game, color: color)
        expect(path.color).to eq(color)
      end
    end
  end
end
