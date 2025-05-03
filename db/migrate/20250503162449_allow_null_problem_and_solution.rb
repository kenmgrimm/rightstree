class AllowNullProblemAndSolution < ActiveRecord::Migration[7.1]
  def change
    # Change problem and solution columns to allow NULL values
    change_column_null :patent_applications, :problem, true
    change_column_null :patent_applications, :solution, true

    # Add default empty string values for existing records with NULL values
    # This ensures existing records remain valid while allowing new records to have NULL values
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE patent_applications#{' '}
          SET problem = ''#{' '}
          WHERE problem IS NULL;

          UPDATE patent_applications#{' '}
          SET solution = ''#{' '}
          WHERE solution IS NULL;
        SQL
      end
    end
  end
end
