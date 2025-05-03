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

    # Add user message to chat history with timestamp
    timestamp = Time.current.to_i
    @patent_application.chat_history << { role: "user", content: user_message, timestamp: timestamp }

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

    # Update chat history with AI response
    @patent_application.chat_history = result[:messages]
    @patent_application.save

    # Extract AI suggestions
    suggested_problem, suggested_solution, chat = PatentService.extract_problem_solution_from_history(@patent_application.chat_history)

    Rails.logger.debug("[PatentApplicationsController#chat] AI response: #{chat}")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested problem: #{suggested_problem}")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested solution: #{suggested_solution}")

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

        # Then add the AI response to the chat container
        ai_streams = [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "assistant", content: chat, timestamp: Time.current.to_i } }
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
