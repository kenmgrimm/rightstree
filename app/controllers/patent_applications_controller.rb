# app/controllers/patent_applications_controller.rb
#
# Controller for managing patent applications with problem-solution pairs
# and AI-assisted guidance through Hotwire (Turbo and Stimulus).
#
# This controller handles:
# - Creating and editing patent applications
# - Persisting problem and solution text
# - Facilitating AI chat interactions through PatentService

class PatentApplicationsController < ApplicationController
  before_action :set_patent_application, only: [ :show, :edit, :update, :mark_complete, :publish, :chat, :update_problem, :update_solution ]

  # GET /patent_applications
  # Lists all patent applications owned by the current user
  def index
    Rails.logger.debug("[PatentApplicationsController#index] Listing all patent applications")

    # Get all patent applications (would be scoped to current_user in a real app)
    @patent_applications = PatentApplication.all.order(updated_at: :desc)

    # Group applications by status for easier display
    @draft_applications = @patent_applications.select(&:draft?)
    @complete_applications = @patent_applications.select(&:complete?)
    @published_applications = @patent_applications.select(&:published?)

    Rails.logger.debug("[PatentApplicationsController#index] Found #{@patent_applications.size} applications: " +
                      "#{@draft_applications.size} drafts, " +
                      "#{@complete_applications.size} complete, " +
                      "#{@published_applications.size} published")
  end

  # GET /patent_applications/marketplace
  # Displays published patent applications available for browsing/bidding/purchasing
  def marketplace
    Rails.logger.debug("[PatentApplicationsController#marketplace] Showing patent marketplace")

    # Only show published applications in the marketplace
    @marketplace_patents = PatentApplication.where(status: "published").order(updated_at: :desc)

    # In a real app, we might have additional filtering options here
    # such as by category, price range, etc.

    Rails.logger.debug("[PatentApplicationsController#marketplace] Found #{@marketplace_patents.size} published patents")
  end

  # GET /patent_applications/new
  # Renders the form for a new patent application
  def new
    Rails.logger.debug("[PatentApplicationsController#new] Initializing new patent application form")
    @patent_application = PatentApplication.new
  end

  # GET /patent_applications/create_stub
  # Creates a stub patent application and redirects to the edit page
  # This ensures we're always working with a persisted record
  def create_stub
    Rails.logger.debug("[PatentApplicationsController#create_stub] Creating stub patent application")

    # Generate a default title with timestamp to ensure uniqueness
    default_title = "Patent Application #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    Rails.logger.debug("[PatentApplicationsController#create_stub] Generated default title: #{default_title}")

    # Create the patent application with the default title
    @patent_application = PatentApplication.create(title: default_title)

    if @patent_application.persisted?
      Rails.logger.debug("[PatentApplicationsController#create_stub] Created stub patent application: #{@patent_application.id} with title: #{@patent_application.title}")
      # Redirect to edit path to ensure consistent user experience
      redirect_to edit_patent_application_path(@patent_application)
    else
      Rails.logger.error("[PatentApplicationsController#create_stub] Failed to create patent application: #{@patent_application.errors.full_messages.join(', ')}")
      # Fallback to the home page with an error message
      redirect_to root_path, alert: "Unable to create a new patent application: #{@patent_application.errors.full_messages.join(', ')}. Please try again."
    end
  end

  # POST /patent_applications
  # Creates a new patent application with the provided problem and solution
  def create
    Rails.logger.debug("[PatentApplicationsController#create] Creating patent application with params: #{patent_application_params.inspect}")
    @patent_application = PatentApplication.new(patent_application_params)

    respond_to do |format|
      if @patent_application.save
        Rails.logger.debug("[PatentApplicationsController#create] Successfully created patent application: #{@patent_application.id}")
        format.html { redirect_to patent_application_path(@patent_application), notice: "Patent application was successfully created." }
        format.turbo_stream {
          flash.now[:notice] = "Patent application was successfully created."
          render turbo_stream: turbo_stream.replace(
            "patent_application_form",
            partial: "patent_applications/form",
            locals: { patent_application: @patent_application }
          )
        }
      else
        Rails.logger.debug("[PatentApplicationsController#create] Failed to create patent application: #{@patent_application.errors.full_messages}")
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "patent_application_form",
            partial: "patent_applications/form",
            locals: { patent_application: @patent_application }
          )
        }
      end
    end
  end

  # GET /patent_applications/:id
  # Shows the patent application with problem, solution, and chat history
  def show
    Rails.logger.debug("[PatentApplicationsController#show] Showing patent application: #{@patent_application.id}")
  end

  # GET /patent_applications/:id/edit
  # Renders the form for editing an existing patent application
  def edit
    Rails.logger.debug("[PatentApplicationsController#edit] Editing patent application: #{@patent_application.id}")
    Rails.logger.debug("[PatentApplicationsController#edit] Chat history size: #{@patent_application.chat_history&.size || 0}")
  end

  # PATCH/PUT /patent_applications/:id
  # Updates the patent application with the provided problem and solution
  def update
    Rails.logger.debug("[PatentApplicationsController#update] Updating patent application: #{@patent_application.id} with params: #{patent_application_params.inspect}")

    respond_to do |format|
      if @patent_application.update(patent_application_params)
        Rails.logger.debug("[PatentApplicationsController#update] Successfully updated patent application: #{@patent_application.id}")
        format.html { redirect_to patent_application_path(@patent_application), notice: "Patent application was successfully updated." }
        format.turbo_stream {
          flash.now[:notice] = "Patent application was successfully updated."
          render turbo_stream: [
            turbo_stream.replace(
              "patent_application_#{@patent_application.id}",
              partial: "patent_applications/patent_application",
              locals: { patent_application: @patent_application }
            ),
            turbo_stream.replace(
              "flash",
              partial: "shared/flash"
            )
          ]
        }
      else
        Rails.logger.debug("[PatentApplicationsController#update] Failed to update patent application: #{@patent_application.errors.full_messages}")
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "patent_application_form",
            partial: "patent_applications/form",
            locals: { patent_application: @patent_application }
          )
        }
      end
    end
  end

  # POST /patent_applications/:id/chat
  # Processes a chat message for an existing patent application and returns the AI response using Turbo Streams
  def chat
    # Get the user's message and optional problem/solution from the form
    user_message = params[:message]
    problem = params[:problem].presence
    solution = params[:solution].presence

    Rails.logger.debug("[PatentApplicationsController#chat] Processing chat message for patent application #{params[:id]}: #{user_message}")

    # Find the patent application - it must exist since this is a member route
    @patent_application = PatentApplication.find(params[:id])
    Rails.logger.debug("[PatentApplicationsController#chat] Using patent application: #{@patent_application.id}")

    # Update problem/solution if provided but not already set
    if problem.present? && @patent_application.problem.blank?
      @patent_application.update(problem: problem)
      Rails.logger.debug("[PatentApplicationsController#chat] Updated problem field")
    end

    if solution.present? && @patent_application.solution.blank?
      @patent_application.update(solution: solution)
      Rails.logger.debug("[PatentApplicationsController#chat] Updated solution field")
    end

    # Initialize chat history if it doesn't exist
    @patent_application.chat_history ||= []

    # Add user message to chat history
    user_message = params[:message].to_s.strip
    Rails.logger.debug("[PatentApplicationsController#chat] Processing user message: #{user_message}") if Rails.env.development?

    # Add the user message to the chat history using the new standardized format
    user_standardized_msg = standardize_message({
      role: "user",
      content: user_message,
      patent_application_id: @patent_application.id
    })

    @patent_application.chat_history << user_standardized_msg

    # Save the patent application to persist the user message
    @patent_application.save

    # Debug logging for the standardized message
    Rails.logger.debug("[PatentApplicationsController#chat] Added standardized user message: #{user_standardized_msg.inspect}") if Rails.env.development?

    # Debug logging
    Rails.logger.debug("[PatentApplicationsController#chat] Added user message: #{user_message}")
    Rails.logger.debug("[PatentApplicationsController#chat] Chat history after adding user message: #{@patent_application.chat_history.size} messages")

    # Process with PatentService
    result = PatentService.guide_problem_solution(
      messages: @patent_application.chat_history,
      user_input: user_message,
      current_problem: @patent_application.problem,
      current_solution: @patent_application.solution,
      update_problem: false,
      update_solution: false
    )

    Rails.logger.debug("### result")
    pp result

    # Extract AI response and suggestions from the result with nil checks
    ai_message = result[:ai_message] if result.is_a?(Hash)
    suggested_problem = result[:ai_suggested_problem] if result.is_a?(Hash)
    suggested_solution = result[:ai_suggested_solution] if result.is_a?(Hash)

    # Add comprehensive debug logging
    Rails.logger.debug("[PatentApplicationsController#chat] AI message: #{ai_message.inspect}")

    # Extract chat content from AI message with error handling
    extracted_chat = nil
    begin
      if ai_message.present?
        # Extract the problem, solution, and chat content from the AI message
        _, _, extracted_chat = PatentService.extract_problem_solution_from_history([ { role: "assistant", content: ai_message } ])
        Rails.logger.debug("[PatentApplicationsController#chat] Successfully extracted chat content: #{extracted_chat.inspect}")
      end
    rescue => e
      Rails.logger.error("[PatentApplicationsController#chat] Error extracting chat content: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    # Use extracted_chat if available, otherwise use a cleaned version of the AI message
    display_content = if extracted_chat.present?
      # Use the extracted chat content
      Rails.logger.debug("[PatentApplicationsController#chat] Using extracted chat content: #{extracted_chat[0..100]}...")
      extracted_chat
    elsif ai_message.present?
      # If we couldn't extract the chat content but have the AI message, try to extract just the chat part
      if ai_message.include?("```json")
        begin
          json_block = ai_message[/```json\s*(\{.*?\})\s*```/m, 1]
          if json_block.present?
            parsed = JSON.parse(json_block)
            if parsed["chat"].present?
              Rails.logger.debug("[PatentApplicationsController#chat] Extracted chat from AI message: #{parsed["chat"][0..100]}...")
              parsed["chat"]
            else
              Rails.logger.debug("[PatentApplicationsController#chat] No chat content in JSON, using cleaned message")
              ai_message.gsub(/```json|```/m, "").strip
            end
          else
            Rails.logger.debug("[PatentApplicationsController#chat] No JSON block found, using cleaned message")
            ai_message.gsub(/```json|```/m, "").strip
          end
        rescue => e
          Rails.logger.error("[PatentApplicationsController#chat] Error parsing JSON in AI message: #{e.message}")
          ai_message.gsub(/```json|```/m, "").strip
        end
      else
        # No JSON formatting, just use the message as is
        Rails.logger.debug("[PatentApplicationsController#chat] No JSON formatting, using message as is")
        ai_message
      end
    else
      # Fallback message if we have no content
      Rails.logger.warn("[PatentApplicationsController#chat] No AI message or extracted chat content available")
      "I'm sorry, I couldn't process that request properly."
    end

    # Debug logging for extracted content
    Rails.logger.debug("[PatentApplicationsController#chat] Extracted chat content: #{extracted_chat.inspect}")
    Rails.logger.debug("[PatentApplicationsController#chat] Using display_content: #{display_content.inspect}")

    # Extract problem and solution from the AI response
    problem, solution, message_text = extract_problem_solution_message(display_content)

    # Log the extracted values
    Rails.logger.debug("[PatentApplicationsController#chat] Extracted problem: #{problem.inspect}") if Rails.env.development?
    Rails.logger.debug("[PatentApplicationsController#chat] Extracted solution: #{solution.inspect}") if Rails.env.development?
    Rails.logger.debug("[PatentApplicationsController#chat] Extracted message text: #{message_text.inspect}") if Rails.env.development?

    # Add AI response to chat history with proper content for display
    if ai_message.present?
      # Create a standardized AI response message using the new format
      # Pass the extracted values directly to standardize_message to avoid nesting
      ai_response = standardize_message({
        role: "assistant",
        content: message_text || display_content,
        problem: problem || "",
        solution: solution || "",
        patent_application_id: @patent_application.id
      })

      # Add comprehensive debug logging
      Rails.logger.debug("[PatentApplicationsController#chat] Storing AI response with standardized format") if Rails.env.development?

      # Add the message to chat history
      @patent_application.chat_history << ai_response

      # Save the updated chat history
      if @patent_application.save
        Rails.logger.debug("[PatentApplicationsController#chat] Successfully saved chat history with #{@patent_application.chat_history.size} messages")
      else
        Rails.logger.error("[PatentApplicationsController#chat] Failed to save chat history: #{@patent_application.errors.full_messages.join(', ')}")
      end
    end

    Rails.logger.debug("[PatentApplicationsController#chat] Updated chat history with #{@patent_application.chat_history.size} messages")
    Rails.logger.debug("[PatentApplicationsController#chat] Chat history: #{@patent_application.chat_history.inspect}")

    # Log the extracted information
    Rails.logger.debug("[PatentApplicationsController#chat] AI response: #{display_content ? display_content[0..100] : 'nil'}...")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested problem: #{suggested_problem}")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested solution: #{suggested_solution}")

    # Log the chat history in a safe way
    history_summary = if @patent_application.chat_history.present?
      @patent_application.chat_history.map do |m|
        role = m[:role].to_s
        content_preview = m[:content] ? m[:content].to_s[0..30] : "nil"
        "#{role}: #{content_preview}..."
      end.join(", ")
    else
      "<empty>"
    end

    Rails.logger.debug("[PatentApplicationsController#chat] Chat history after processing: #{history_summary}")

    respond_to do |format|
      format.turbo_stream {
        # Add the user message to the chat container
        # Create a timestamp for the message display
        current_timestamp = Time.current.to_i

        user_streams = [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "user", message: user_message, timestamp: current_timestamp, patent_application_id: @patent_application.id } }
          )
        ]

        # Add the AI response to the stream
        ai_streams = [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: ai_response }
          ),
          # Update the chat form with the current state
          turbo_stream.replace(
            "chat_form",
            partial: "patent_applications/chat_form",
            locals: { patent_application: @patent_application }
          ),
          # Update the patent application ID in the form (for new applications)
          turbo_stream.replace(
            "patent_application_id",
            partial: "patent_applications/patent_application_id",
            locals: { patent_application: @patent_application }
          )
        ]

        # Combine all streams
        render turbo_stream: user_streams + ai_streams
      }
    end
  end

  # PATCH /patent_applications/:id/update_problem
  # Updates the problem statement with an AI suggestion
  def update_problem
    Rails.logger.debug("[PatentApplicationsController#update_problem] Updating problem for patent application: #{@patent_application.id}")
    Rails.logger.debug("[PatentApplicationsController#update_problem] New problem: #{params[:problem]}")

    if @patent_application.update(problem: params[:problem])
      Rails.logger.debug("[PatentApplicationsController#update_problem] Successfully updated problem")
      flash[:notice] = "Problem statement updated."
    else
      Rails.logger.debug("[PatentApplicationsController#update_problem] Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}")
      flash[:alert] = "Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}"
    end

    redirect_to edit_patent_application_path(@patent_application)
  end

  # Updates the solution with an AI suggestion
  def update_solution
    Rails.logger.debug("[PatentApplicationsController#update_solution] Updating solution for patent application: #{@patent_application.id}")
    Rails.logger.debug("[PatentApplicationsController#update_solution] New solution: #{params[:solution]}")

    if @patent_application.update(solution: params[:solution])
      Rails.logger.debug("[PatentApplicationsController#update_solution] Successfully updated solution")
      flash[:notice] = "Solution updated."
    else
      Rails.logger.debug("[PatentApplicationsController#update_solution] Failed to update solution: #{@patent_application.errors.full_messages.join(', ')}")
      flash[:alert] = "Failed to update solution: #{@patent_application.errors.full_messages.join(', ')}"
    end

    redirect_to edit_patent_application_path(@patent_application)
  end

  # PATCH /patent_applications/:id/mark_complete
  # Marks a patent application as complete, validating required fields
  def mark_complete
    Rails.logger.debug("[PatentApplicationsController#mark_complete] Marking patent application as complete: #{@patent_application.id}")

    if @patent_application.problem.blank? || @patent_application.solution.blank?
      Rails.logger.debug("[PatentApplicationsController#mark_complete] Cannot mark as complete - missing required fields")
      flash[:alert] = "Cannot mark as complete. Please ensure both problem and solution are provided."
      redirect_to edit_patent_application_path(@patent_application)
    else
      if @patent_application.mark_as_complete
        Rails.logger.debug("[PatentApplicationsController#mark_complete] Successfully marked as complete")
        flash[:notice] = "Patent application marked as complete."
        redirect_to patent_application_path(@patent_application)
      else
        Rails.logger.debug("[PatentApplicationsController#mark_complete] Failed to mark as complete: #{@patent_application.errors.full_messages.join(', ')}")
        flash[:alert] = "Failed to mark as complete: #{@patent_application.errors.full_messages.join(', ')}"
        redirect_to edit_patent_application_path(@patent_application)
      end
    end
  end

  # PATCH /patent_applications/:id/publish
  # Publishes a complete patent application
  def publish
    Rails.logger.debug("[PatentApplicationsController#publish] Publishing patent application: #{@patent_application.id}")

    unless @patent_application.complete?
      Rails.logger.debug("[PatentApplicationsController#publish] Cannot publish - not marked as complete")
      flash[:alert] = "Patent application must be marked as complete before publishing."
      redirect_to patent_application_path(@patent_application)
      return
    end

    if @patent_application.publish
      Rails.logger.debug("[PatentApplicationsController#publish] Successfully published")
      flash[:notice] = "Patent application has been published successfully."
    else
      Rails.logger.debug("[PatentApplicationsController#publish] Failed to publish: #{@patent_application.errors.full_messages}")
      flash[:alert] = "Could not publish: #{@patent_application.errors.full_messages.join(', ')}"
    end

    redirect_to patent_application_path(@patent_application)
  end

  private

  # Sets the patent application instance variable from the id parameter
  def set_patent_application
    @patent_application = PatentApplication.find(params[:id])
    Rails.logger.debug("[PatentApplicationsController#set_patent_application] Found patent application: #{@patent_application.id}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[PatentApplicationsController#set_patent_application] Patent application not found: #{params[:id]}")
    redirect_to root_path, alert: "Patent application not found."
  end

  # Standardize new messages for consistent format (without modifying old data)
  # This ensures all new messages follow the standardized format:
  # system: { role:, message:, timestamp: }
  # user: { role:, message:, timestamp: }
  # assistant: { role:, timestamp:, content: { problem:, solution:, message: } }
  def standardize_message(message)
    # Get current timestamp if not provided
    timestamp = message[:timestamp] || message["timestamp"] || Time.current.to_i
    role = message[:role] || message["role"]
    patent_app_id = message[:patent_application_id] || message["patent_application_id"] || @patent_application&.id

    # Create a standardized message based on role
    case role
    when "system", "user"
      # For system and user messages, use the simple format with message
      standardized = {
        "role" => role,
        "message" => message[:content] || message["content"] || "",
        "timestamp" => timestamp,
        "patent_application_id" => patent_app_id
      }
    when "assistant"
      # For assistant messages, handle content and extract problem/solution
      content = message[:content] || message["content"] || ""

      # Get problem and solution directly from message or default to empty string
      problem = message[:problem] || message["problem"] || ""
      solution = message[:solution] || message["solution"] || ""

      # If we have raw content that needs parsing and no problem/solution provided
      if content.is_a?(String) && !problem.present? && !solution.present?
        # Try to extract problem/solution from JSON if present
        problem, solution, extracted_message = extract_problem_solution_message(content)
        message_text = extracted_message || content
      elsif content.is_a?(Hash) && content["message"].present?
        # If content is already a hash with message field, extract it to avoid nesting
        message_text = content["message"]
        # Also check if the hash has problem/solution fields
        problem = content["problem"] if content["problem"].present? && !problem.present?
        solution = content["solution"] if content["solution"].present? && !solution.present?
      else
        message_text = content
      end

      # Debug logging
      Rails.logger.debug("[PatentApplicationsController#standardize_message] Processing assistant message: content=#{content.class}, problem=#{problem}, solution=#{solution}") if Rails.env.development?

      # Create the standardized assistant message
      standardized = {
        "role" => "assistant",
        "timestamp" => timestamp,
        "patent_application_id" => patent_app_id,
        "content" => {
          "problem" => problem,
          "solution" => solution,
          "message" => message_text
        }
      }
    else
      # Default case for unknown roles
      standardized = {
        "role" => role,
        "message" => message[:content] || message["content"] || "",
        "timestamp" => timestamp,
        "patent_application_id" => patent_app_id
      }
    end

    # Add debug logging
    Rails.logger.debug("[PatentApplicationsController#standardize_message] Standardized message: #{standardized.inspect}") if Rails.env.development?

    # Return the standardized message
    standardized
  end

  # Helper method to extract problem, solution, and message from content
  def extract_problem_solution_message(content)
    return [ "", "", content ] unless content.present?

    # Check if the content looks like JSON
    if content.include?("{")
      # Try to extract JSON from code blocks
      if content.include?("```json")
        json_block = content[/```json\s*(\{.*?\})\s*```/m, 1]
        content_to_parse = json_block if json_block.present?
      else
        # Try to find JSON directly in the content
        json_match = content.match(/\{.*\}/m)
        content_to_parse = json_match[0] if json_match
      end

      # If we found JSON to parse, extract the fields
      if content_to_parse.present?
        begin
          parsed = JSON.parse(content_to_parse)

          # Extract fields based on what's available
          problem = parsed["problem"] if parsed["problem"].present?
          solution = parsed["solution"] if parsed["solution"].present?

          # Look for message in different possible fields
          message = parsed["message"] || parsed["chat"] || ""

          # If we found structured data, return it
          if problem || solution || message
            return [ problem || "", solution || "", message ]
          end
        rescue => e
          Rails.logger.error("[PatentApplicationsController#extract_problem_solution_message] JSON parsing error: #{e.message}")
        end
      end
    end

    # If we couldn't extract structured data, return the original content as the message
    [ "", "", content.gsub(/```json|```/m, "").strip ]
  end

  # Permits the allowed parameters for creating/updating a patent application
  def patent_application_params
    Rails.logger.debug("[PatentApplicationsController#patent_application_params] Processing parameters: #{params[:patent_application].inspect}")
    params.require(:patent_application).permit(:title, :problem, :solution, :status)
  end
end
