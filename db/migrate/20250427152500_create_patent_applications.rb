# db/migrate/20250427152500_create_patent_applications.rb
#
# Migration to create the patent_applications table
# This table stores problem-solution pairs and associated chat history

class CreatePatentApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :patent_applications do |t|
      t.text :problem, null: false
      t.text :solution, null: false
      t.jsonb :chat_history, default: []
      t.integer :user_id  # Optional, for future user association

      t.timestamps
    end
    
    add_index :patent_applications, :user_id
  end
end
