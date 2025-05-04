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

    # We'll handle the system prompt in standardize_messages_for_openai
    # No need to add it here

    # Add the current user input to the messages
    # Only if it's not already the last user message (avoid duplicates)
    last_user_message = messages.reverse.find { |m| (m[:role] || m["role"]).to_s == "user" }
    last_user_content = last_user_message ? (last_user_message[:content] || last_user_message["content"]).to_s : nil

    if last_user_content != user_input
      messages << { role: "user", content: user_input }
      Rails.logger.debug("[PatentService] Added user input to messages: #{user_input}")
    else
      Rails.logger.debug("[PatentService] User input already in messages, not adding duplicate")
    end

    # Log the conversation history size
    Rails.logger.debug("[PatentService] Conversation history size: #{messages.size} messages")

    # Standardize the messages for OpenAI API
    standardized_messages = standardize_messages_for_openai(messages)

    Rails.logger.debug("[PatentService] Conversation so far: #{standardized_messages.inspect}")

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
    response = OpenaiService.new.chat(standardized_messages, temperature: 0.6, max_tokens: 500)
    Rails.logger.debug("[PatentService] OpenAI response: #{response.inspect}")
    ai_message = response.dig("choices", 0, "message", "content")
    messages << { role: "assistant", content: ai_message }

    # Log the AI response to the console without colors
    puts "\nAI: #{ai_message}"

    # binding.break

    # Extract AI-suggested problem/solution/title from latest assistant message
    ai_suggested_problem, ai_suggested_solution, _, ai_suggested_title = extract_problem_solution_from_history(messages)
    Rails.logger.debug("[PatentService] AI-suggested problem: #{ai_suggested_problem.inspect}")
    Rails.logger.debug("[PatentService] AI-suggested solution: #{ai_suggested_solution.inspect}")
    Rails.logger.debug("[PatentService] AI-suggested title: #{ai_suggested_title.inspect}")

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
      ai_suggested_solution: ai_suggested_solution,
      ai_suggested_title: ai_suggested_title
    }
  end

  # System prompt for the AI
  def self.system_prompt
    <<~PROMPT.strip
      You are a patent expert. Guide the user through a structured process to define a technical problem and solution suitable for a patent application. Follow the conversation flow strictly in this order:

      CONVERSATION FLOW - YOU MUST FOLLOW THIS ORDER:
      1. First, help the user clearly define the PROBLEM
         - Ask: "What technical area are you interested in?"
         - Ask: "What specific challenge or limitation are you facing?"
         - Ask: "Why is this a problem? What impact does it have?"
         - Ask: "In what context or domain does this problem occur?"
      2. Once the problem is well-defined, suggest a concise TITLE
         - Provide a title that captures the core technical problem
         - Ask: "Does this title accurately reflect the problem we've defined?"
      3. Only after the problem and title are established, discuss the SOLUTION
         - Ask: "What solution are you proposing for this problem?"
         - Ask: "How does your solution address the specific challenges we identified?"

      DO NOT ask about solutions until you have helped the user fully define the problem and have suggested a title. This is critical.

      PROBLEM STATEMENT GUIDELINES:
      - DO NOT simply repeat what the user says as the problem statement
      - Analyze the user's input and extract the underlying technical problem
      - A good problem statement should include:
        1. The specific technical challenge or limitation
        2. Why this is a problem (impact or consequences)
        3. The context or domain where this problem occurs
      - Rewrite vague or incomplete problem descriptions into comprehensive statements
      - If the user provides an incomplete problem description, ask clarifying questions
      - When suggesting a problem statement, be assertive and direct:
        * "The core technical problem is..."
        * "This is a significant challenge because..."
        * "The technical context for this problem is..."
      - Make definitive statements, not tentative observations
      - Provide clear reasoning for your problem formulation

      TITLE GUIDELINES:
      - Create a concise, descriptive title under 15 words
      - Focus on the core technical problem being solved
      - Use specific terminology relevant to the field
      - Avoid generic phrases like "system and method for"

      Important:
      - At the end of every message, output your response as a JSON object in a single code block, like this:
      {
        "problem": "A concise but comprehensive problem statement here that includes the technical challenge, impact, and context.",
        "solution": "A concise solution statement here.",
        "title": "A condensed title under 15 words focusing on the core technical problem.",
        "message": "Conversational text, clarifications, or next questions for the user."
      }
      - Always include all four fields: "problem", "solution", "title", and "message" in your JSON response, even if one is empty. If a value is unknown or not yet provided, use an empty string (""). Never omit a field or use null.
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
    return [ nil, nil, nil, nil ] unless last_assistant && last_assistant[:content]
    text = last_assistant[:content]

    Rails.logger.debug("[PatentService] Extracting from content: #{text[0..100]}...")

    # Check if the content looks like raw JSON (starts with ```json)
    if text.strip.start_with?("```json")
      # Extract the JSON block
      json_block = text[/```json\s*(\{.*?\})\s*```/m, 1]

      if json_block
        begin
          Rails.logger.debug("[PatentService] Found JSON block: #{json_block}")
          parsed = JSON.parse(json_block)
          problem = parsed["problem"]
          solution = parsed["solution"]
          title = parsed["title"]
          message = parsed["message"] || parsed["chat"] # Support both message and chat fields

          # Log the extracted values
          Rails.logger.debug("[PatentService] Extracted message: #{message.inspect}")
          Rails.logger.debug("[PatentService] Extracted problem: #{problem.inspect}")
          Rails.logger.debug("[PatentService] Extracted solution: #{solution.inspect}")
          Rails.logger.debug("[PatentService] Extracted title: #{title.inspect}")

          # Return the extracted message content instead of the raw JSON
          if message.present? || problem.present? || solution.present? || title.present?
            return [ problem, solution, message, title ]
          end
        rescue JSON::ParserError => e
          Rails.logger.warn("[PatentService] JSON parse error: #{e.message}")
        end
      end
    end

    # clean the text by removing JSON code blocks
    cleaned_text = text.gsub(/```json.*?```/m, "").strip

    if cleaned_text.present?
      Rails.logger.debug("[PatentService] Using cleaned text: #{cleaned_text}")
      return [ nil, nil, cleaned_text, nil ]
    end

    # If all else fails, use the entire response but remove the code block markers
    final_text = text.gsub(/```.*?```/m, "").strip
    [ nil, nil, final_text, nil ]
  end

  # Standardize messages for OpenAI API to ensure consistent format and maintain conversation context
  # OpenAI API expects each message to have 'role' and 'content' keys
  def self.standardize_messages_for_openai(messages)
    Rails.logger.debug("[PatentService#standardize_messages_for_openai] Standardizing #{messages.size} messages")

    # First, ensure we have the system prompt as the first message
    system_prompt_message = { "role" => "system", "content" => system_prompt }

    # Extract and clean up the conversation history
    conversation = []

    # Process each message to extract the actual conversation
    messages.each do |msg|
      # Skip any empty or nil messages
      next if msg.nil? || (msg.is_a?(Hash) && msg.empty?)

      # Extract role - could be symbol or string key
      role = (msg[:role] || msg["role"]).to_s

      # Skip system messages that aren't the main system prompt
      # We'll add our own system prompt at the beginning
      next if role == "system" && msg != messages.first

      # For user messages
      if role == "user"
        # Extract content from either content or message field
        content = msg[:message] || msg["message"] || msg[:content] || msg["content"]
        # Skip empty messages
        next if content.nil? || content.to_s.strip.empty?
        conversation << { "role" => "user", "content" => content.to_s }

      # For assistant messages
      elsif role == "assistant"
        content_hash = msg[:content] || msg["content"]

        # Handle different formats of assistant messages
        if content_hash.is_a?(Hash) && (content_hash["message"] || content_hash[:message])
          # If it's our standardized format with a message field, use that
          content = content_hash["message"] || content_hash[:message]
        else
          # Otherwise use the content directly
          content = content_hash
        end

        # Skip empty messages
        next if content.nil? || content.to_s.strip.empty?
        conversation << { "role" => "assistant", "content" => content.to_s }
      end
    end

    # Construct the final message array with system prompt first, then conversation
    standardized = [ system_prompt_message ] + conversation

    # Log the standardized messages
    Rails.logger.debug("[PatentService#standardize_messages_for_openai] Standardized #{standardized.size} messages")
    Rails.logger.debug("[PatentService#standardize_messages_for_openai] First few messages: #{standardized[0..2].inspect}") if Rails.env.development?

    standardized
  end
end
