
module PerformEvery
  class ActiveRecordGenerator < Rails::Generators::Base
    include Rails::Generators::Migration
    source_root File.expand_path("../templates", __FILE__)

    def copy_migration
      migration_template "migration.rb", "db/migrate/create_perform_every.rb"
    end

    #def generate_model
      #invoke "active_record:model", ["PerformEvery"], migration: false unless model_exists? && behavior == :invoke
    #end

    private 

    # see https://stackoverflow.com/questions/11079617/next-migration-number-notimplementederror-notimplementederror-using-wysihat
    def self.next_migration_number(dirname)
      next_migration_number = current_migration_number(dirname) + 1
      ActiveRecord::Migration.next_migration_number(next_migration_number)
    end

    #def model_exists?
      #File.exist?(File.join(destination_root, model_path))
    #end

    #def model_path
      #@model_path ||= File.join("app", "models", "perform_every.rb")
    #end
  end
end
