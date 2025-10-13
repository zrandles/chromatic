class GamesController < ApplicationController
  # Skip CSRF for game creation (simple game, no user auth)
  skip_forgery_protection only: [:create, :play_card, :end_turn]

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
      redirect_to game_path(@game), notice: 'Card played successfully!'
    else
      redirect_to game_path(@game), alert: result[:error]
    end
  end

  def end_turn
    @game = Game.find(params[:id])
    @game.end_turn
    redirect_to game_path(@game)
  end
end
