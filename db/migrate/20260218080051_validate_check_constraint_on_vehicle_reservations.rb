# frozen_string_literal: true

class ValidateCheckConstraintOnVehicleReservations < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :vehicle_reservations, name: 'starts_at_less_than_ends_at'
  end
end
