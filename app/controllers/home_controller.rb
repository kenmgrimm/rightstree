# app/controllers/home_controller.rb
#
# Controller for the home page and landing pages
# Provides entry points to the application's main features

class HomeController < ApplicationController
  # GET /
  # Renders the home page with options to create a new patent application
  def index
    Rails.logger.debug("[HomeController#index] Rendering home page")
  end
end
