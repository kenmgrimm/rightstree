class AddTitleToPatentApplications < ActiveRecord::Migration[8.0]
  def change
    # Add title column with not null constraint (will apply to new records only)
    add_column :patent_applications, :title, :string

    # Add a unique index scoped to user_id
    # This ensures titles are unique per user but allows different users to use the same titles
    add_index :patent_applications, [ :user_id, :title ], unique: true, name: 'index_patent_applications_on_user_id_and_title'

    # Add default titles to existing records
    # This is necessary because we're going to add a NOT NULL constraint
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE patent_applications
          SET title = 'Patent Application #' || id
          WHERE title IS NULL
        SQL

        # Add NOT NULL constraint after setting default values
        change_column_null :patent_applications, :title, false
      end
    end
  end
end
