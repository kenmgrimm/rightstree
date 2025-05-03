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
  before_action :set_patent_application, only: [ :show, :edit, :update, :mark_complete, :publish, :chat ]

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

    @patent_application = PatentApplication.create

    if @patent_application.persisted?
      Rails.logger.debug("[PatentApplicationsController#create_stub] Created stub patent application: #{@patent_application.id}")
      # Redirect to edit path to ensure consistent user experience
      redirect_to edit_patent_application_path(@patent_application)
    else
      Rails.logger.error("[PatentApplicationsController#create_stub] Failed to create patent application: #{@patent_application.errors.full_messages.join(', ')}")
      # Fallback to the home page with an error message
      redirect_to root_path, alert: "Unable to create a new patent application. Please try again."
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
    
    # Debug logging
    Rails.logger.debug("[PatentApplicationsController#chat] Chat history before adding user message: #{@patent_application.chat_history.inspect}")

    # Add user message to chat history with timestamp
    timestamp = Time.current.to_i
    @patent_application.chat_history << { role: "user", content: user_message, timestamp: timestamp }
    
    # Debug logging
    Rails.logger.debug("[PatentApplicationsController#chat] Added user message: #{user_message}")
    Rails.logger.debug("[PatentApplicationsController#chat] Chat history after adding user message: #{@patent_application.chat_history.inspect}")

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
        _, _, extracted_chat = PatentService.extract_problem_solution_from_history([{role: "assistant", content: ai_message}])
        Rails.logger.debug("[PatentApplicationsController#chat] Successfully extracted chat content: #{extracted_chat.inspect}")
      end
    rescue => e
      Rails.logger.error("[PatentApplicationsController#chat] Error extracting chat content: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
    
    # Use extracted_chat if available, otherwise use a cleaned version of the AI message
    display_content = if extracted_chat.present?
      extracted_chat
    elsif ai_message.present?
      # Clean up the message by removing JSON formatting
      ai_message.gsub(/```json|```/m, "").strip
    else
      "I'm sorry, I couldn't process that request properly."
    end
    
    # Debug logging for extracted content
    Rails.logger.debug("[PatentApplicationsController#chat] Extracted chat content: #{extracted_chat.inspect}")
    Rails.logger.debug("[PatentApplicationsController#chat] Using display_content: #{display_content.inspect}")
    
    # Add AI response to chat history with proper content for display
    if ai_message.present?
      # Make sure we're storing the parsed chat content, not the raw JSON
      Rails.logger.debug("[PatentApplicationsController#chat] Adding AI response to chat history: #{display_content ? display_content[0..100] : 'nil'}...")
      
      # Store the properly formatted message in the chat history
      @patent_application.chat_history << { role: "assistant", content: display_content, timestamp: Time.current.to_i }
      
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
        content_preview = m[:content] ? m[:content].to_s[0..30] : 'nil'
        "#{role}: #{content_preview}..."
      end.join(', ')
    else
      "<empty>"
    end
    
    Rails.logger.debug("[PatentApplicationsController#chat] Chat history after processing: #{history_summary}")

    respond_to do |format|
      format.turbo_stream {
        # Add the user message to the chat container
        user_streams = [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "user", content: user_message, timestamp: timestamp } }
          )
        ]

        # Then add the AI response to the chat container with error handling
        safe_content = display_content.present? ? display_content : "I'm sorry, I couldn't process that request properly."
        Rails.logger.debug("[PatentApplicationsController#chat] Using safe_content for display: #{safe_content[0..100]}...")
        
        ai_streams = [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "assistant", content: safe_content, timestamp: Time.current.to_i } }
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

  # PATCH /patent_applications/:id/mark_complete
  # Marks a patent application as complete, validating required fields
  def mark_complete
    Rails.logger.debug("[PatentApplicationsController#mark_complete] Marking patent application as complete: #{@patent_application.id}")

    if @patent_application.problem.blank? || @patent_application.solution.blank?
      Rails.logger.debug("[PatentApplicationsController#mark_complete] Cannot mark as complete - missing required fields")
      flash[:alert] = "Cannot mark as complete. Please ensure both problem and solution are provided."
      redirect_to edit_patent_application_path(@patent_application)
      return
    end

    if @patent_application.mark_as_complete
      Rails.logger.debug("[PatentApplicationsController#mark_complete] Successfully marked as complete")
      flash[:notice] = "Patent application marked as complete and ready for publishing."
    else
      Rails.logger.debug("[PatentApplicationsController#mark_complete] Failed to mark as complete: #{@patent_application.errors.full_messages}")
      flash[:alert] = "Could not mark as complete: #{@patent_application.errors.full_messages.join(', ')}"
    end

    redirect_to patent_application_path(@patent_application)
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

  # Permits the allowed parameters for creating/updating a patent application
  def patent_application_params
    params.require(:patent_application).permit(:problem, :solution, :status)
  end
end
