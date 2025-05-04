Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Patent Application routes
  # These routes handle the patent application web form with AI chat integration
  # Note: We use create_stub instead of :new for patent application creation
  resources :patent_applications, only: [ :index, :create, :show, :edit, :update ] do
    collection do
      # Route for creating a stub patent application and redirecting to edit
      get :create_stub

      # Route for the patent marketplace (published patents)
      get :marketplace
    end

    member do
      # Route for setting the title of a patent application
      get :set_title

      # Route for updating the title of a patent application
      patch :update_title

      # Route for AI chat interactions with existing applications only
      post :chat

      # Route for updating problem statement from AI suggestions
      patch :update_problem

      # Route for updating solution from AI suggestions
      patch :update_solution

      # Route for marking an application as complete (ready for publishing)
      patch :mark_complete

      # Route for publishing a complete application
      patch :publish
    end
  end

  # Defines the root path route ("/")
  # Set the root route to the home page with options to create a new patent application
  root "home#index"
end
