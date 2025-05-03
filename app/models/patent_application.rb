# app/models/patent_application.rb
#
# The PatentApplication model represents a patent application with problem and solution statements.
# It also stores the chat history for context and future reference.
#
# Schema:
# - problem: text - The technical problem statement
# - solution: text - The proposed solution statement
# - chat_history: jsonb - The history of AI chat interactions
# - user_id: integer - Optional association with a user (if authentication is present)
# - created_at, updated_at: timestamps

class PatentApplication < ApplicationRecord
  # Define possible statuses
  STATUSES = {
    draft: "draft",           # Initial status, minimal validation
    complete: "complete",     # All required fields filled, ready for review
    published: "published"    # Finalized and published
  }

  # Set default status to draft
  attribute :status, :string, default: STATUSES[:draft]

  # Conditional validations based on status
  with_options if: :publishing_or_published? do
    validates :problem, presence: true
    validates :solution, presence: true
  end

  # Ensure chat_history is always an array of messages
  before_validation :ensure_chat_history_structure

  # Debug logging
  after_initialize :log_initialize
  after_save :log_save
  after_update :log_update

  # Returns a summary of the patent application
  def summary
    {
      id: id,
      problem: problem,
      solution: solution,
      chat_count: chat_history&.size || 0,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Status management methods
  def draft?
    status == STATUSES[:draft]
  end

  def complete?
    status == STATUSES[:complete]
  end

  def published?
    status == STATUSES[:published]
  end

  private

  # Ensures chat_history is properly structured as an array
  def ensure_chat_history_structure
    self.chat_history ||= []
    Rails.logger.debug("[PatentApplication] Ensuring chat_history structure: #{chat_history.inspect}")
  end

  def publishing_or_published?
    status.to_s == STATUSES[:complete] || status.to_s == STATUSES[:published]
  end

  def mark_as_complete
    update(status: STATUSES[:complete])
  end

  def publish
    if valid?
      update(status: STATUSES[:published])
    else
      errors.add(:base, "Cannot publish incomplete application")
      false
    end
  end

  # Debug logging methods
  def log_initialize
    Rails.logger.debug("[PatentApplication] Initialized: #{attributes.inspect}")
  end

  def log_save
    Rails.logger.debug("[PatentApplication] Saved: #{id}, problem: #{problem&.truncate(50)}, solution: #{solution&.truncate(50)}")
  end

  def log_update
    Rails.logger.debug("[PatentApplication] Updated: #{id}, problem: #{problem&.truncate(50)}, solution: #{solution&.truncate(50)}")
  end
end
