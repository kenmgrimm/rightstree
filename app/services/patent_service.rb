# app/services/patent_service.rb
# Guides users to create a problem-solution pair for a patent using OpenaiService
# Includes debug logging for all steps

class PatentService
  # Multi-turn guided conversation for problem-solution discovery
  # Params:
  #   messages: Array of conversation messages (each: {role:, content:})
  #   user_input: String (latest user message)
  # Returns: Hash with :problem, :solution, :messages, :ai_message, :raw_response
  # Guides the user to articulate a clear problem and solution for a patent, with persistent state.
  # Params:
  #   messages: Array of conversation messages
  #   user_input: String (latest user message)
  #   current_problem: String (current canonical problem, or nil)
  #   current_solution: String (current canonical solution, or nil)
  #   update_problem: Boolean (explicit user request to update problem)
  #   update_solution: Boolean (explicit user request to update solution)
  # Returns: Hash with :problem, :solution, :messages, :ai_message, :raw_response, :ai_suggested_problem, :ai_suggested_solution
  def self.guide_problem_solution(messages:, user_input:, current_problem: nil, current_solution: nil, update_problem: false, update_solution: false)
    Rails.logger.debug("[PatentService] Received user_input: #{user_input.inspect}")
    messages ||= []
    # System prompt always first
    if messages.empty? || messages.first[:role] != "system"
      messages.unshift({ role: "system", content: system_prompt })
    end
    # Always include current problem/solution as context
    if current_problem
      messages << { role: "assistant", content: "Current Problem: #{current_problem}" }
    end
    if current_solution
      messages << { role: "assistant", content: "Current Solution: #{current_solution}" }
    end

    # If there is no current solution, ensure the AI only prompts the user to provide one, not to generate it
    if current_solution.nil? || current_solution.strip.empty?
      # Mark in context that the user must provide the solution
      messages << { role: "system", content: "Do not propose or extrapolate a solution until the user provides one. Only prompt the user to describe their own solution." }
    end
    messages << { role: "user", content: user_input }
    Rails.logger.debug("[PatentService] Conversation so far: #{messages.inspect}")

    # Check for off-topic requests (basic heuristic)
    if off_topic?(user_input)
      redirect_message = "Let's focus on defining your problem and solution for the patent application. Please describe the technical problem you want to solve."
      messages << { role: "assistant", content: redirect_message }
      Rails.logger.info("[PatentService] Off-topic detected, redirecting user.")
      return {
        problem: current_problem,
        solution: current_solution,
        messages: messages,
        ai_message: redirect_message,
        raw_response: nil,
        ai_suggested_problem: nil,
        ai_suggested_solution: nil
      }
    end

    # Send to OpenAI
    response = OpenaiService.new.chat(messages, temperature: 0.6, max_tokens: 500)
    Rails.logger.debug("[PatentService] OpenAI response: #{response.inspect}")
    ai_message = response.dig("choices", 0, "message", "content")
    messages << { role: "assistant", content: ai_message }

    # Log the AI response to the console without colors
    puts "\nAI: #{ai_message}"

    # binding.break

    # Extract AI-suggested problem/solution from latest assistant message
    ai_suggested_problem, ai_suggested_solution = extract_problem_solution_from_history(messages)
    Rails.logger.debug("[PatentService] AI-suggested problem: #{ai_suggested_problem.inspect}, solution: #{ai_suggested_solution.inspect}")

    # Only update canonical fields if explicitly requested
    new_problem = update_problem && ai_suggested_problem ? ai_suggested_problem : current_problem
    new_solution = update_solution && ai_suggested_solution ? ai_suggested_solution : current_solution

    {
      problem: new_problem,
      solution: new_solution,
      messages: messages,
      ai_message: ai_message,
      raw_response: response,
      ai_suggested_problem: ai_suggested_problem,
      ai_suggested_solution: ai_suggested_solution
    }
  end

  # System prompt for the AI
  def self.system_prompt
    <<~PROMPT.strip
      You are a patent expert. Guide the user to clearly define a technical problem and a novel solution suitable for a patent application. Ask clarifying questions as needed. Only respond to requests related to the problem and solution discovery process.

      Here are some example questions you can use to prompt the user:
      - "What technical area are you interested in?"
      - "Do you have a product or service in mind?"
      - "What is the problem you are trying to solve?"
      - "Do you have an existing patent application that your problem or solution is attempting to address?"
      - "Describe to me the solution you are suggesting to address the problem."
      - "Can you summarize the problem in 1-3 sentences?"
      - "Can you describe your solution in a short paragraph?"

      Important:
      - At the end of every message, output your response as a JSON object in a single code block, like this:
      ```json
      {
        "problem": "A concise problem statement here.",
        "solution": "A concise solution statement here.",
        "chat": "Conversational text, clarifications, or next questions for the user."
      }
      ```
      - Always include all three fields: "problem", "solution", and "chat" in your JSON response, even if one is empty. If a value is unknown or not yet provided, use an empty string (""). Never omit a field or use null.
      - Only include this code block in your response. Do not include any other text outside the code block.
      - If you are not sure, ask the user for clarification before proposing a summary.

      If the user asks something unrelated to the problem and solution discovery process, politely remind them to focus on defining a clear technical problem and solution for their patent application.
    PROMPT
  end

  # Heuristic for off-topic user requests
  def self.off_topic?(user_input)
    # Add more patterns as needed
    unrelated = [
      /weather|joke|news|movie|music|restaurant|sports/i,
      /unrelated|not about patent|off topic/i
    ]
    unrelated.any? { |pat| user_input =~ pat }
  end

  # Extracts the latest problem and solution from the most recent assistant message
  require "json"

  def self.extract_problem_solution_from_history(messages)
    last_assistant = messages.reverse.find { |m| m[:role] == "assistant" }
    return [ nil, nil, nil ] unless last_assistant && last_assistant[:content]
    text = last_assistant[:content]
    
    Rails.logger.debug("[PatentService] Extracting from content: #{text[0..100]}...")

    # Check if the content looks like raw JSON (starts with ```json)
    if text.strip.start_with?('```json')
      # Extract the JSON block
      json_block = text[/```json\s*(\{.*?\})\s*```/m, 1]
      
      if json_block
        begin
          Rails.logger.debug("[PatentService] Found JSON block: #{json_block}")
          parsed = JSON.parse(json_block)
          problem = parsed["problem"]
          solution = parsed["solution"]
          chat = parsed["chat"]
          
          # Log the extracted values
          Rails.logger.debug("[PatentService] Extracted chat: #{chat.inspect}")
          Rails.logger.debug("[PatentService] Extracted problem: #{problem.inspect}")
          Rails.logger.debug("[PatentService] Extracted solution: #{solution.inspect}")
          
          # Return the extracted chat content instead of the raw JSON
          if chat.present?
            return [ problem, solution, chat ]
          end
        rescue JSON::ParserError => e
          Rails.logger.warn("[PatentService] JSON parse error: #{e.message}")
        end
      end
    end
    
    # If we couldn't extract from JSON or some fields were missing,
    # clean the text by removing JSON code blocks
    cleaned_text = text.gsub(/```json.*?```/m, "").strip
    
    if cleaned_text.present?
      Rails.logger.debug("[PatentService] Using cleaned text: #{cleaned_text}")
      return [ nil, nil, cleaned_text ]
    end
    
    # If all else fails, use the entire response but remove the code block markers
    cleaned_response = text.gsub(/```json|```/m, "").strip
    Rails.logger.debug("[PatentService] Using cleaned response: #{cleaned_response[0..100]}...")
    [ nil, nil, cleaned_response ]
  end
end
