# frozen_string_literal: true

class VehicleStatus
  DRAFT = 'draft'
  PUBLISHED = 'published'
  VALID_STATUSES = [
    DRAFT,
    PUBLISHED
  ].freeze
end
