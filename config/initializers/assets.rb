# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add our image paths explicitly
Rails.application.config.assets.paths << Rails.root.join("app/assets/images")

# Enable serving of static assets
Rails.application.config.public_file_server.enabled = true
