class AddStatusToPatentApplications < ActiveRecord::Migration[7.1]
  def change
    add_column :patent_applications, :status, :string, default: 'draft'

    # Add an index for faster queries when filtering by status
    add_index :patent_applications, :status

    # Update existing records to have the default status
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE patent_applications SET status = 'draft'
        SQL
      end
    end
  end
end
