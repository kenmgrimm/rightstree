# app/services/openai_service.rb
# Service object for interacting with OpenAI API (GPT-4, GPT-3.5, etc)
# Loads API key from Rails credentials (preferred) or ENV as fallback.
# Adds debug logging for all requests and responses.

require "openai"

class OpenaiService
  DEFAULT_MODEL = "gpt-4".freeze

  def initialize(model: DEFAULT_MODEL)
    @model = model
    @client = OpenAI::Client.new(access_token: fetch_api_key) # ruby-openai uses access_token:
    Rails.logger.debug("[OpenaiService] Initialized with model: #{@model}")
  end

  # Example: chat completion
  def chat(messages, **options)
    Rails.logger.debug("[OpenaiService] Sending chat request: #{messages.inspect}, opts: #{options.inspect}")
    response = @client.chat(parameters: {
      model: @model,
      messages: messages
    }.merge(options))
    Rails.logger.debug("[OpenaiService] Received response: #{response.inspect}")
    response
  rescue => e
    Rails.logger.error("[OpenaiService] Error: #{e.class}: #{e.message}")
    raise
  end

  private

  def fetch_api_key
    key = Rails.application.credentials.OPENAI_API_TOKEN || ENV["OPENAI_API_TOKEN"]
    unless key
      Rails.logger.error("[OpenaiService] OpenAI API key missing! Set credentials or ENV.")
      raise "OpenAI API key missing!"
    end
    key
  end
end
