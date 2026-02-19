# frozen_string_literal: true

class AddCheckConstrainToVehicleReservations < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :vehicle_reservations,
                         'starts_at < ends_at',
                         name: 'starts_at_less_than_ends_at',
                         validate: false
  end
end
