#!/usr/bin/env ruby
# script/openai_chat.rb
# Usage: rails runner script/openai_chat.rb "Your prompt here"

require_relative "../config/environment"

prompt = ARGV.join(" ")
prompt = "Say hello from OpenAI!" if prompt.strip.empty?

service = OpenaiService.new(model: "gpt-3.5-turbo")
messages = [
  { role: "user", content: prompt }
]

begin
  response = service.chat(messages)
  content = response.dig("choices", 0, "message", "content")
  puts "OpenAI response: #{content}"
rescue => e
  puts "Error: #{e.class}: #{e.message}"
end
