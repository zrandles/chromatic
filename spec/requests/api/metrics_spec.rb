require 'rails_helper'

RSpec.describe 'Api::Metrics', type: :request do
  describe 'GET /chromatic/api/metrics' do
    before do
      # Create some test data
      create_list(:game, 5)
      create_list(:game, 2, :finished, player_score: 150, ai_score: 120)
      create_list(:game, 1, :finished, player_score: 100, ai_score: 130)
      create(:color_path, :red_path, player_type: 'player')
      create(:color_path, :blue_path, player_type: 'ai')
    end

    it 'returns successful response' do
      get '/chromatic/api/metrics'
      expect(response).to have_http_status(:ok)
    end

    it 'returns JSON format' do
      get '/chromatic/api/metrics'
      expect(response.content_type).to match(/application\/json/)
    end

    it 'includes app name' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['app_name']).to eq('chromatic')
    end

    it 'includes environment' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['environment']).to eq('test')
    end

    it 'includes timestamp' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['timestamp']).to be_present
    end

    it 'includes engagement metrics' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['engagement']).to be_present
      expect(json['engagement']['metric_name']).to eq('Games Played (7 days)')
      expect(json['engagement']['metric_value']).to be >= 0
    end

    it 'includes custom game metrics' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['custom']['games']).to be_present
      expect(json['custom']['games']['total']).to be >= 8
      expect(json['custom']['games']['finished']).to eq(3)
    end

    it 'includes gameplay statistics' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['custom']['gameplay']).to be_present
      expect(json['custom']['gameplay']['avg_player_score']).to be_present
      expect(json['custom']['gameplay']['player_win_rate']).to be_present
    end

    it 'includes color path statistics' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['custom']['color_paths']).to be_present
      expect(json['custom']['color_paths']['total']).to be >= 2
    end

    it 'includes health metrics' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      expect(json['health']).to be_present
      expect(json['health']['database']).to be true
      expect(json['health']['cache']).to be true
    end

    it 'calculates player win rate correctly' do
      get '/chromatic/api/metrics'
      json = JSON.parse(response.body)
      # 2 player wins out of 3 finished games = 66.7%
      expect(json['custom']['gameplay']['player_win_rate']).to be_within(0.1).of(66.7)
    end

    context 'when metrics collection fails' do
      before do
        allow_any_instance_of(Api::MetricsController).to receive(:custom_metrics).and_raise(StandardError.new('Test error'))
      end

      it 'returns error response' do
        get '/chromatic/api/metrics'
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'includes error message' do
        get '/chromatic/api/metrics'
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Metrics collection failed')
        expect(json['message']).to eq('Test error')
      end
    end

    context 'with no games' do
      before do
        Game.destroy_all
        ColorPath.destroy_all
      end

      it 'returns zero metrics gracefully' do
        get '/chromatic/api/metrics'
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['custom']['games']['total']).to eq(0)
        expect(json['custom']['gameplay']['player_win_rate']).to eq(0)
      end
    end
  end
end
