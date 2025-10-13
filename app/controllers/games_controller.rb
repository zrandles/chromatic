class GamesController < ApplicationController
  # Skip CSRF for game creation (simple game, no user auth)
  skip_forgery_protection only: [:create, :play_card, :end_turn, :continue_round]

  def index
    @games = Game.order(created_at: :desc).limit(10)
  end

  def show
    @game = Game.find(params[:id])
  end

  def create
    @game = Game.create!
    redirect_to game_path(@game)
  end

  def play_card
    @game = Game.find(params[:id])
    result = @game.play_card(
      params[:card_index].to_i,
      params[:color],
      'player'
    )

    if result[:success]
      drew_cards = result[:drew_cards] || 1
      redirect_to game_path(@game), notice: "Card played! Drew #{drew_cards} card#{'s' if drew_cards > 1}."
    else
      redirect_to game_path(@game), alert: result[:error]
    end
  end

  def end_turn
    @game = Game.find(params[:id])
    @game.end_turn
    redirect_to game_path(@game)
  end

  def continue_round
    @game = Game.find(params[:id])
    @game.continue_to_next_round
    redirect_to game_path(@game), notice: "Starting Round #{@game.current_round}!"
  end
end
