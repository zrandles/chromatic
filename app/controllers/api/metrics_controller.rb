# Business Metrics API for App Monitor Integration
#
# Customized for Chromatic - 5-color card game
#
class Api::MetricsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_metrics_token, if: :token_required?

  def show
    render json: {
      app_name: detect_app_name,
      environment: Rails.env,
      timestamp: Time.current.iso8601,
      version: app_version,

      # Business metrics
      revenue: revenue_metrics,
      users: user_metrics,
      engagement: engagement_metrics,

      # Operational health
      health: health_metrics,

      # Game-specific metrics
      custom: custom_metrics
    }
  rescue => e
    render json: {
      error: "Metrics collection failed",
      message: e.message,
      timestamp: Time.current.iso8601
    }, status: :internal_server_error
  end

  private

  # No revenue tracking for game
  def revenue_metrics
    nil
  end

  # No user accounts in chromatic
  def user_metrics
    nil
  end

  # Key engagement metric: games played
  def engagement_metrics
    {
      metric_name: "Games Played (7 days)",
      metric_value: Game.where("created_at > ?", 7.days.ago).count,
      metric_unit: "games",
      details: {
        today: Game.where("created_at > ?", 1.day.ago).count,
        this_week: Game.where("created_at > ?", 7.days.ago).count,
        this_month: Game.where("created_at > ?", 30.days.ago).count
      }
    }
  end

  # Game-specific metrics
  def custom_metrics
    {
      games: {
        total: Game.count,
        active: Game.where(status: 'active').count,
        finished: Game.where(status: 'finished').count,
        today: Game.where("created_at > ?", 1.day.ago).count
      },
      gameplay: {
        avg_player_score: Game.where(status: 'finished').average(:player_score)&.round(1),
        avg_ai_score: Game.where(status: 'finished').average(:ai_score)&.round(1),
        player_win_rate: calculate_player_win_rate,
        avg_rounds: Game.where(status: 'finished').average(:current_round)&.round(1)
      },
      color_paths: {
        total: ColorPath.count,
        by_color: ColorPath.group(:color).count,
        avg_per_game: (ColorPath.count.to_f / Game.count).round(1)
      }
    }
  end

  def calculate_player_win_rate
    finished = Game.where(status: 'finished')
    return 0 if finished.count.zero?

    player_wins = finished.where("player_score > ai_score").count
    ((player_wins.to_f / finished.count) * 100).round(1)
  end

  # Health checks
  def health_metrics
    {
      database: database_connected?,
      cache: cache_connected?,
      jobs: jobs_healthy?,
      storage: storage_connected?
    }
  end

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue
    false
  end

  def cache_connected?
    Rails.cache.write("health_check", "ok", expires_in: 1.second)
    Rails.cache.read("health_check") == "ok"
  rescue
    false
  end

  def jobs_healthy?
    if defined?(SolidQueue)
      SolidQueue::Job.count >= 0
      true
    else
      nil
    end
  rescue
    false
  end

  def storage_connected?
    if defined?(ActiveStorage)
      ActiveStorage::Blob.count >= 0
      true
    else
      nil
    end
  rescue
    false
  end

  def app_version
    if File.exist?(Rails.root.join("VERSION"))
      File.read(Rails.root.join("VERSION")).strip
    elsif File.exist?(Rails.root.join(".git/refs/heads/main"))
      File.read(Rails.root.join(".git/refs/heads/main")).strip[0..7]
    else
      "unknown"
    end
  end

  # Security
  def token_required?
    Rails.env.production?
  end

  def verify_metrics_token
    expected_token = Rails.application.credentials.dig(:metrics_api_token)
    return true unless expected_token.present?

    provided_token = request.headers["Authorization"]&.gsub("Bearer ", "")

    unless provided_token == expected_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def detect_app_name
    if Rails.root.basename.to_s != "current"
      return Rails.root.basename.to_s
    end

    if Rails.root.to_s.include?("/home/zac/") && Rails.root.basename.to_s == "current"
      return Rails.root.parent.parent.basename.to_s
    end

    Rails.application.class.module_parent_name.underscore
  end
end
