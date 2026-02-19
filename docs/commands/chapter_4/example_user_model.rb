# frozen_string_literal: true

class User < ApplicationRecord
  validates :email, :username, presence: true
  validates :email, uniqueness: true
  validates :username, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, if: :password_present?
  validates :age, numericality: { only_integer: true, greater_than_or_equal_to: 13 }, allow_nil: true
  validates :role, inclusion: { in: %w[user admin moderator] }

  validate :username_cannot_contain_spaces

  private

  def username_cannot_contain_spaces
    return unless username&.include?(' ')

    errors.add(:username, 'cannot contain spaces')
  end

  def password_present?
    password.present?
  end
end
