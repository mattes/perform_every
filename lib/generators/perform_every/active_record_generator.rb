
module PerformEvery
  class ActiveRecordGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path("../templates", __FILE__)

    def copy_migration
      migration_template "migration.rb", "db/migrate/create_perform_every.rb"
    end

    private 

    # see https://stackoverflow.com/questions/11079617/next-migration-number-notimplementederror-notimplementederror-using-wysihat
    def self.next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end
  end
end
