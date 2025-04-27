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
  resources :patent_applications, only: [:new, :create, :show, :edit, :update] do
    member do
      # Route for AI chat interactions with saved applications
      post :ai_chat
    end
    
    collection do
      # Route for AI chat interactions with unsaved applications
      post :chat
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
  
  # Set the root route to the new patent application form
  root "patent_applications#new"
end
