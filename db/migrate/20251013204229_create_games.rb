class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.string :status
      t.integer :current_round
      t.integer :total_rounds
      t.integer :player_score
      t.integer :ai_score
      t.text :game_state

      t.timestamps
    end
  end
end
