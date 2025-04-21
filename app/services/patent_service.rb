# app/services/patent_service.rb
# Guides users to create a problem-solution pair for a patent using OpenaiService
# Includes debug logging for all steps

class PatentService
  # Guides the user to articulate a clear problem and solution for a patent
  # Params:
  #   user_input: String (initial user description or idea)
  # Returns: Hash with :problem, :solution, :ai_messages, and :raw_response
  def self.guide_problem_solution(user_input)
    Rails.logger.debug("[PatentService] Starting problem-solution guidance with user_input: #{user_input.inspect}")
    messages = [
      { role: "system", content: "You are a patent expert. Help the user clearly define a technical problem and a novel solution suitable for a patent application. Ask clarifying questions if needed." },
      { role: "user", content: user_input }
    ]
    response = OpenaiService.new.chat(messages, temperature: 0.6, max_tokens: 500)
    Rails.logger.debug("[PatentService] OpenAI response: #{response.inspect}")
    ai_message = response.dig("choices", 0, "message", "content")

    # Attempt to extract structured problem/solution (AI may return as text)
    problem, solution = extract_problem_solution(ai_message)
    {
      problem: problem,
      solution: solution,
      ai_messages: [ ai_message ],
      raw_response: response
    }
  end

  # Helper to extract problem and solution from AI output (basic heuristic)
  def self.extract_problem_solution(text)
    problem = text[/problem[:\s-]*(.+?)(?:solution[:\s-]|$)/im, 1]&.strip
    solution = text[/solution[:\s-]*(.+)/im, 1]&.strip
    [ problem, solution ]
  end
end
