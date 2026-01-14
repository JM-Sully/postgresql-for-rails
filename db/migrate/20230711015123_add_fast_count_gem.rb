# frozen_string_literal: true

class AddFastCountGem < ActiveRecord::Migration[7.1]
  def change
    FastCount.install
  end
end
