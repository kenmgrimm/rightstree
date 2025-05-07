# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add our image paths explicitly
Rails.application.config.assets.paths << Rails.root.join("app/assets/images")

# Precompile additional assets
Rails.application.config.assets.precompile += %w( *.png *.jpg *.jpeg *.gif *.svg )

# Enable serving of static assets in production
Rails.application.config.public_file_server.enabled = true
