class CreateColorPaths < ActiveRecord::Migration[8.0]
  def change
    create_table :color_paths do |t|
      t.references :game, null: false, foreign_key: true
      t.string :color
      t.text :cards_data
      t.integer :score
      t.string :player_type

      t.timestamps
    end
  end
end
