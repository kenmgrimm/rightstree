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
  before_action :set_patent_application, only: [ :show, :edit, :update, :mark_complete, :publish, :chat, :update_problem, :update_solution, :set_title, :update_title ]

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
  # Creates a new patent application without a title and redirects to the edit page
  # The title can remain unset until transitioning out of draft status
  def create_stub
    Rails.logger.debug("[PatentApplicationsController#create_stub] Creating new patent application")

    # Create a new patent application without a title
    # The user can set a title whenever they want
    @patent_application = PatentApplication.new

    if @patent_application.save
      Rails.logger.debug("[PatentApplicationsController#create_stub] Created new patent application: #{@patent_application.id}")
      # Redirect directly to edit page
      redirect_to edit_patent_application_path(@patent_application)
    else
      Rails.logger.error("[PatentApplicationsController#create_stub] Failed to create patent application: #{@patent_application.errors.full_messages.join(', ')}")
      # Fallback to the home page with an error message
      redirect_to root_path, alert: "Unable to create a new patent application: #{@patent_application.errors.full_messages.join(', ')}. Please try again."
    end
  end

  # GET /patent_applications/:id/set_title
  # Shows a form for setting the patent application title
  def set_title
    Rails.logger.debug("[PatentApplicationsController#set_title] Showing title form for patent application: #{@patent_application.id}")

    # If the patent application already has a non-temporary title, redirect to edit
    if @patent_application.title.present? && !@patent_application.title.start_with?("[Temporary Title")
      Rails.logger.debug("[PatentApplicationsController#set_title] Patent application already has a title: #{@patent_application.title}")
      redirect_to edit_patent_application_path(@patent_application)
    end
  end

  # PATCH /patent_applications/:id/update_title
  # Updates the patent application title
  def update_title
    Rails.logger.debug("[PatentApplicationsController#update_title] Updating title for patent application: #{@patent_application.id}")
    Rails.logger.debug("[PatentApplicationsController#update_title] New title: #{params[:title]}")
    Rails.logger.debug("[PatentApplicationsController#update_title] Current problem: #{@patent_application.problem}")

    # Preserve the current problem statement when updating the title
    current_problem = @patent_application.problem

    # Update both title and problem (to ensure problem is preserved)
    if @patent_application.update(title: params[:title], problem: current_problem)
      Rails.logger.debug("[PatentApplicationsController#update_title] Successfully updated title while preserving problem")

      # Add a system message to the chat history indicating the title was accepted
      add_title_acceptance_to_chat_history(params[:title])

      flash[:notice] = "Title was successfully set."
      redirect_to edit_patent_application_path(@patent_application)
    else
      Rails.logger.debug("[PatentApplicationsController#update_title] Failed to update title: #{@patent_application.errors.full_messages.join(', ')}")
      flash.now[:alert] = "Failed to set title: #{@patent_application.errors.full_messages.join(', ')}"
      render :set_title
    end
  end

  # Helper method to add a title acceptance message to the chat history
  def add_title_acceptance_to_chat_history(title_text)
    Rails.logger.debug("[PatentApplicationsController#add_title_acceptance_to_chat_history] Adding title acceptance to chat history")

    # Create a system message indicating the title was accepted
    system_message = {
      role: "system",
      content: "Title accepted: #{title_text}",
      timestamp: Time.current.to_i
    }

    # Add the message to chat history
    @patent_application.chat_history << system_message

    # Save the updated chat history
    if @patent_application.save
      Rails.logger.debug("[PatentApplicationsController#add_title_acceptance_to_chat_history] Successfully saved chat history with title acceptance")
    else
      Rails.logger.error("[PatentApplicationsController#add_title_acceptance_to_chat_history] Failed to save chat history: #{@patent_application.errors.full_messages.join(', ')}")
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

    # Allow patent application to be viewed even without a proper title
    # Just log that the title is temporary or missing
    if @patent_application.title.blank? || @patent_application.title.start_with?("[Temporary Title")
      Rails.logger.debug("[PatentApplicationsController#show] Patent application does not have a proper title, but proceeding anyway")
    end
  end

  # GET /patent_applications/:id/edit
  # Renders the form for editing an existing patent application
  def edit
    Rails.logger.debug("[PatentApplicationsController#edit] Editing patent application: #{@patent_application.id}")

    # Allow patent application to be edited even without a proper title
    # Just log that the title is temporary or missing
    if @patent_application.title.blank? || @patent_application.title.start_with?("[Temporary Title")
      Rails.logger.debug("[PatentApplicationsController#edit] Patent application does not have a proper title, but proceeding anyway")
    end

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

    # Allow chat even without a proper title
    # Just log that the title is temporary or missing
    if @patent_application.title.blank? || @patent_application.title.start_with?("[Temporary Title")
      Rails.logger.debug("[PatentApplicationsController#chat] Patent application does not have a proper title, but proceeding anyway")
    end

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
    suggested_title = result[:ai_suggested_title] if result.is_a?(Hash)

    # Log the suggested title
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested title: #{suggested_title.inspect}")

    # Add comprehensive debug logging
    Rails.logger.debug("[PatentApplicationsController#chat] AI message: #{ai_message.inspect}")

    # Extract chat content from AI message with error handling
    extracted_chat = nil
    begin
      if ai_message.present?
        # Extract the problem, solution, chat content, and title from the AI message
        _, _, extracted_chat, _ = PatentService.extract_problem_solution_from_history([ { role: "assistant", content: ai_message } ])
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

    # Use the suggested problem, solution, and title directly from the PatentService result
    problem = suggested_problem
    solution = suggested_solution
    title = suggested_title

    # Log the extracted values
    Rails.logger.debug("[PatentApplicationsController#chat] Using problem from result: #{problem.inspect}") if Rails.env.development?
    Rails.logger.debug("[PatentApplicationsController#chat] Using solution from result: #{solution.inspect}") if Rails.env.development?
    Rails.logger.debug("[PatentApplicationsController#chat] Using title from result: #{title.inspect}") if Rails.env.development?

    # Extract message text from the JSON response
    message_text = nil
    begin
      if ai_message.present? && ai_message.include?("```json")
        json_block = ai_message[/```json\s*(\{.*?\})\s*```/m, 1]
        if json_block.present?
          parsed = JSON.parse(json_block)
          message_text = parsed["message"]
          Rails.logger.debug("[PatentApplicationsController#chat] Extracted message from JSON: #{message_text.inspect}") if Rails.env.development?
        end
      end
    rescue => e
      Rails.logger.error("[PatentApplicationsController#chat] Error extracting message from JSON: #{e.message}")
    end

    # If we couldn't extract the message text, use the display_content
    message_text ||= display_content

    # Add AI response to chat history with proper content for display
    if ai_message.present?
      # Create a standardized AI response message using the new format
      ai_response = standardize_message({
        role: "assistant",
        content: message_text,
        problem: problem || "",
        solution: solution || "",
        title: title || "",
        patent_application_id: @patent_application.id
      })

      # Log the AI response with title
      Rails.logger.debug("[PatentApplicationsController#chat] AI response with title: #{ai_response.inspect}") if Rails.env.development?

      # Add comprehensive debug logging
      Rails.logger.debug("[PatentApplicationsController#chat] Storing AI response with standardized format") if Rails.env.development?

      # Add the message to chat history (and ensure we don't add duplicate messages)
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

    # Check for AI-suggested title
    problem_text = params[:problem]
    ai_title = params[:ai_title]

    # Log the AI-suggested title if present
    if ai_title.present?
      Rails.logger.debug("[PatentApplicationsController#update_problem] Using AI-suggested title: #{ai_title}")
    end

    # Log the current problem for debugging
    Rails.logger.debug("[PatentApplicationsController#update_problem] Current problem: #{@patent_application.problem}")

    # Determine which title to use
    if @patent_application.title.blank? || @patent_application.title.empty?
      # If we have an AI-suggested title, use it
      if ai_title.present?
        title = ai_title
        Rails.logger.debug("[PatentApplicationsController#update_problem] Using AI-suggested title: #{title}")
      # Otherwise generate one from the problem
      elsif problem_text.present?
        Rails.logger.debug("[PatentApplicationsController#update_problem] Generating title from problem statement")
        title = generate_title_from_problem(problem_text)
        Rails.logger.debug("[PatentApplicationsController#update_problem] Generated title: #{title}")
      end

      # Update both problem and title if we have a title
      if title.present?
        if @patent_application.update(problem: problem_text, title: title)
          Rails.logger.debug("[PatentApplicationsController#update_problem] Successfully updated problem and title")
          flash[:notice] = "Problem statement updated and title generated."

          # Add a system message to the chat history indicating the problem was accepted
          add_problem_acceptance_to_chat_history(problem_text)
        else
          Rails.logger.debug("[PatentApplicationsController#update_problem] Failed to update problem and title: #{@patent_application.errors.full_messages.join(', ')}")
          flash[:alert] = "Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}"
        end
      else
        # Just update the problem if we couldn't generate a title
        if @patent_application.update(problem: problem_text)
          Rails.logger.debug("[PatentApplicationsController#update_problem] Successfully updated problem")
          flash[:notice] = "Problem statement updated."

          # Add a system message to the chat history indicating the problem was accepted
          add_problem_acceptance_to_chat_history(problem_text)
        else
          Rails.logger.debug("[PatentApplicationsController#update_problem] Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}")
          flash[:alert] = "Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}"
        end
      end
    else
      # Just update the problem if title already exists
      if @patent_application.update(problem: problem_text)
        Rails.logger.debug("[PatentApplicationsController#update_problem] Successfully updated problem")
        flash[:notice] = "Problem statement updated."

        # Add a system message to the chat history indicating the problem was accepted
        add_problem_acceptance_to_chat_history(problem_text)
      else
        Rails.logger.debug("[PatentApplicationsController#update_problem] Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}")
        flash[:alert] = "Failed to update problem: #{@patent_application.errors.full_messages.join(', ')}"
      end
    end

    redirect_to edit_patent_application_path(@patent_application)
  end

  # Helper method to add a problem acceptance message to the chat history
  def add_problem_acceptance_to_chat_history(problem_text)
    Rails.logger.debug("[PatentApplicationsController#add_problem_acceptance_to_chat_history] Adding problem acceptance to chat history")

    # Create a system message indicating the problem was accepted
    system_message = {
      role: "system",
      content: "Problem statement accepted: #{problem_text}",
      timestamp: Time.current.to_i
    }

    # Add the message to chat history
    @patent_application.chat_history << system_message

    # Save the updated chat history
    if @patent_application.save
      Rails.logger.debug("[PatentApplicationsController#add_problem_acceptance_to_chat_history] Successfully saved chat history with problem acceptance")
    else
      Rails.logger.error("[PatentApplicationsController#add_problem_acceptance_to_chat_history] Failed to save chat history: #{@patent_application.errors.full_messages.join(', ')}")
    end
  end

  # Updates the solution with an AI suggestion
  def update_solution
    Rails.logger.debug("[PatentApplicationsController#update_solution] Updating solution for patent application: #{@patent_application.id}")
    Rails.logger.debug("[PatentApplicationsController#update_solution] New solution: #{params[:solution]}")

    # If title is empty and we have a problem statement, generate a title
    if @patent_application.title.blank? && @patent_application.problem.present?
      Rails.logger.debug("[PatentApplicationsController#update_solution] Title is empty, generating from problem")
      title = generate_title_from_problem(@patent_application.problem)
      Rails.logger.debug("[PatentApplicationsController#update_solution] Generated title: #{title}")

      if @patent_application.update(solution: params[:solution], title: title)
        Rails.logger.debug("[PatentApplicationsController#update_solution] Successfully updated solution and title")
        flash[:notice] = "Solution updated and title generated."
      else
        Rails.logger.debug("[PatentApplicationsController#update_solution] Failed to update solution and title: #{@patent_application.errors.full_messages.join(', ')}")
        flash[:alert] = "Failed to update solution: #{@patent_application.errors.full_messages.join(', ')}"
      end
    else
      # Just update the solution if title already exists
      if @patent_application.update(solution: params[:solution])
        Rails.logger.debug("[PatentApplicationsController#update_solution] Successfully updated solution")
        flash[:notice] = "Solution updated."
      else
        Rails.logger.debug("[PatentApplicationsController#update_solution] Failed to update solution: #{@patent_application.errors.full_messages.join(', ')}")
        flash[:alert] = "Failed to update solution: #{@patent_application.errors.full_messages.join(', ')}"
      end
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

  # Generate a title from the problem statement
  def generate_title_from_problem(problem_text)
    Rails.logger.debug("[PatentApplicationsController#generate_title_from_problem] Generating title from problem: #{problem_text[0..50]}...")

    # Extract the first sentence or up to 100 characters
    new_title = ""

    if problem_text.present?
      # Try to get the first sentence (ending with period, question mark, or exclamation point)
      first_sentence_match = problem_text.match(/^(.+?[.!?])\s/)

      if first_sentence_match && first_sentence_match[1]
        new_title = first_sentence_match[1].strip
      else
        # If no sentence ending found, take the first 100 chars or the whole text if shorter
        new_title = problem_text[0...[ 100, problem_text.length ].min]
      end

      # Ensure the title isn't too long - truncate to 100 chars if needed
      if new_title.length > 100
        new_title = new_title[0...97] + "..."
      end

      Rails.logger.debug("[PatentApplicationsController#generate_title_from_problem] Generated title: #{new_title}")
    end

    new_title
  end

  # Sets the patent application instance variable from the id parameter
  def set_patent_application
    @patent_application = PatentApplication.find(params[:id])
    Rails.logger.debug("[PatentApplicationsController#set_patent_application] Found patent application: #{@patent_application.id}")
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error("[PatentApplicationsController#set_patent_application] Patent application not found: #{params[:id]}")
    redirect_to root_path, alert: "Patent application not found."
  end

  # Standardizes a message for storage in the chat history
  def standardize_message(message)
    # Ensure we have a timestamp
    timestamp = message[:timestamp] || message["timestamp"] || Time.current.to_i

    # Ensure we have a patent_application_id
    patent_application_id = message[:patent_application_id] || message["patent_application_id"] || @patent_application&.id

    # Get the role
    role = message[:role] || message["role"]

    # For assistant messages, structure the content properly
    if role == "assistant"
      # Get content, which could be a string or a hash
      content = message[:content] || message["content"]
      problem = message[:problem] || message["problem"] || ""
      solution = message[:solution] || message["solution"] || ""
      title = message[:title] || message["title"] || ""

      # If content is a hash, extract message from it
      if content.is_a?(Hash)
        message_text = content[:message] || content["message"] || ""
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
        "patent_application_id" => patent_application_id,
        "content" => {
          "problem" => problem,
          "solution" => solution,
          "title" => title,
          "message" => message_text
        }
      }
    else
      # Default case for unknown roles
      standardized = {
        "role" => role,
        "message" => message[:content] || message["content"] || "",
        "timestamp" => timestamp,
        "patent_application_id" => patent_application_id
      }
    end

    # Add debug logging
    Rails.logger.debug("[PatentApplicationsController#standardize_message] Standardized message: #{standardized.inspect}") if Rails.env.development?

    # Return the standardized message
    standardized
  end

  # Helper method to extract problem, solution, title, and message from content
  def extract_problem_solution_message(content)
    return [ "", "", content, "" ] unless content.present?

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
          title = parsed["title"] if parsed["title"].present?

          # Look for message in different possible fields
          message = parsed["message"] || parsed["chat"] || ""

          # If we found structured data, return it
          if problem || solution || message || title
            Rails.logger.debug("[PatentApplicationsController#extract_problem_solution_message] Extracted title: #{title.inspect}")
            return [ problem || "", solution || "", message, title || "" ]
          end
        rescue => e
          Rails.logger.error("[PatentApplicationsController#extract_problem_solution_message] JSON parsing error: #{e.message}")
        end
      end
    end

    # If we couldn't extract structured data, return the original content as the message
    [ "", "", content.gsub(/```json|```/m, "").strip, "" ]
  end

  # Permits the allowed parameters for creating/updating a patent application
  def patent_application_params
    Rails.logger.debug("[PatentApplicationsController#patent_application_params] Processing parameters: #{params[:patent_application].inspect}")
    params.require(:patent_application).permit(:title, :problem, :solution, :status)
  end
end
