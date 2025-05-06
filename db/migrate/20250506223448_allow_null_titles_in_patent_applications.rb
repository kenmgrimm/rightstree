class AllowNullTitlesInPatentApplications < ActiveRecord::Migration[8.0]
  def change
    # Change the title column to allow null values
    change_column_null :patent_applications, :title, true
    
    # Add a comment to explain the change
    execute <<-SQL
      COMMENT ON COLUMN patent_applications.title IS 'Optional in draft status, required when finalizing';
    SQL
    
    # Log the change for debugging
    puts "[Migration] Changed title column to allow null values"
  end
end
