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
  before_action :set_patent_application, only: [:show, :edit, :update, :ai_chat]
  
  # GET /patent_applications/new
  # Renders the form for a new patent application
  def new
    Rails.logger.debug("[PatentApplicationsController#new] Initializing new patent application form")
    @patent_application = PatentApplication.new
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
  
  # POST /patent_applications/:id/ai_chat
  # Processes a chat message for a saved patent application and returns the AI response using Turbo Streams
  def ai_chat
    Rails.logger.debug("[PatentApplicationsController#ai_chat] Processing AI chat for patent application: #{@patent_application.id}")
    
    # Get the user's message from the form
    user_message = params[:message]
    Rails.logger.debug("[PatentApplicationsController#ai_chat] User message: #{user_message}")
    
    # Initialize chat history if it doesn't exist
    @patent_application.chat_history ||= []
    
    # Add user message to chat history
    @patent_application.chat_history << { role: "user", content: user_message, timestamp: Time.current.to_i }
    
    # Process with PatentService
    result = PatentService.guide_problem_solution(
      messages: @patent_application.chat_history,
      user_input: user_message,
      current_problem: @patent_application.problem,
      current_solution: @patent_application.solution,
      update_problem: false,
      update_solution: false
    )
    
    # Update chat history with AI response
    @patent_application.chat_history = result[:messages]
    @patent_application.save
    
    # Extract AI suggestions
    problem, solution, chat = PatentService.extract_problem_solution_from_history(@patent_application.chat_history)
    
    Rails.logger.debug("[PatentApplicationsController#ai_chat] AI response: #{chat}")
    Rails.logger.debug("[PatentApplicationsController#ai_chat] AI suggested problem: #{problem}")
    Rails.logger.debug("[PatentApplicationsController#ai_chat] AI suggested solution: #{solution}")
    
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "assistant", content: chat } }
          ),
          turbo_stream.replace(
            "chat_form",
            partial: "patent_applications/chat_form",
            locals: { patent_application: @patent_application }
          ),
          turbo_stream.replace(
            "ai_suggestions",
            partial: "patent_applications/ai_suggestions",
            locals: { 
              patent_application: @patent_application,
              suggested_problem: problem,
              suggested_solution: solution
            }
          )
        ]
      }
    end
  end
  
  # POST /patent_applications/chat
  # Processes a chat message for an unsaved patent application and returns the AI response using Turbo Streams
  def chat
    Rails.logger.debug("[PatentApplicationsController#chat] Processing AI chat for unsaved patent application")
    
    # Get the user's message and optional problem/solution from the form
    user_message = params[:message]
    problem = params[:problem].presence
    solution = params[:solution].presence
    
    Rails.logger.debug("[PatentApplicationsController#chat] User message: #{user_message}")
    Rails.logger.debug("[PatentApplicationsController#chat] Current problem: #{problem || '(empty)'}")
    Rails.logger.debug("[PatentApplicationsController#chat] Current solution: #{solution || '(empty)'}")
    
    # Create a temporary patent application to hold the chat history
    @patent_application = PatentApplication.new(problem: problem, solution: solution)
    
    # Initialize chat history with the user's message
    @patent_application.chat_history = [
      { role: "user", content: user_message, timestamp: Time.current.to_i }
    ]
    
    # Process with PatentService
    result = PatentService.guide_problem_solution(
      messages: @patent_application.chat_history,
      user_input: user_message,
      current_problem: problem,
      current_solution: solution,
      update_problem: false,
      update_solution: false
    )
    
    # Update chat history with AI response
    @patent_application.chat_history = result[:messages]
    
    # Extract AI suggestions
    suggested_problem, suggested_solution, chat = PatentService.extract_problem_solution_from_history(@patent_application.chat_history)
    
    Rails.logger.debug("[PatentApplicationsController#chat] AI response: #{chat}")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested problem: #{suggested_problem}")
    Rails.logger.debug("[PatentApplicationsController#chat] AI suggested solution: #{suggested_solution}")
    
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          # Append both the user message and AI response to the chat
          turbo_stream.append(
            "chat_messages",
            partial: "patent_applications/message",
            locals: { message: { role: "user", content: user_message, timestamp: Time.current.to_i } }
          ),
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
          # Update the AI suggestions panel
          turbo_stream.replace(
            "ai_suggestions",
            partial: "patent_applications/ai_suggestions",
            locals: { 
              patent_application: @patent_application,
              suggested_problem: suggested_problem,
              suggested_solution: suggested_solution
            }
          )
        ]
      }
    end
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
    params.require(:patent_application).permit(:problem, :solution)
  end
end
