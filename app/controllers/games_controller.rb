# GamesController - handles player interactions with the Chromatic card game
class GamesController < ApplicationController
  # SECURITY FIX: Re-enable CSRF protection for all actions
  # Game actions now use form_with which automatically includes CSRF tokens
  before_action :set_game, only: [:show, :play_card, :end_turn, :continue_round]
  before_action :validate_game_state, only: [:play_card, :end_turn, :continue_round]

  def index
    @games = Game.order(created_at: :desc).limit(10)
  end

  def show
    # @game set by before_action
  end

  def create
    @game = Game.create!
    redirect_to game_path(@game)
  end

  def play_card
    # SECURITY: Validate input parameters
    unless valid_card_index?(params[:card_index]) && valid_color?(params[:color])
      redirect_to game_path(@game), alert: "Invalid card or color selection" and return
    end

    result = @game.handle_player_card_play(params[:card_index].to_i, params[:color])

    if result[:success]
      drew_cards = result[:drew_cards] || 1
      # Sanitize output to prevent XSS
      redirect_to game_path(@game), notice: "Card played! Drew #{drew_cards} card#{'s' if drew_cards > 1}."
    else
      # Error messages come from model validation, already safe
      redirect_to game_path(@game), alert: result[:error]
    end
  end

  def end_turn
    @game.handle_end_turn
    redirect_to game_path(@game)
  end

  def continue_round
    @game.continue_to_next_round
    deck = @game.game_state['deck']
    cards_remaining = deck.length

    redirect_to game_path(@game), notice: "Round #{@game.current_round} - Paths persist! #{cards_remaining} cards left in deck."
  end

  private

  def set_game
    @game = Game.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Game not found"
  end

  def validate_game_state
    # SECURITY: Validate game state integrity
    unless @game.valid_game_state?
      redirect_to root_path, alert: "Invalid game state detected" and return
    end
  end

  def valid_card_index?(index)
    return false if index.blank?
    index_int = index.to_i
    index_int >= 0 && index_int < @game.player_hand.length
  end

  def valid_color?(color)
    Game::COLORS.include?(color)
  end
end
