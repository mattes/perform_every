class CreatePerformEvery < ActiveRecord::Migration[6.0]
  def change
    create_table :perform_every do |t|
      t.string :job_name
      t.string :typ # every|at
      t.string :value
      t.string :history, array: true
      t.datetime :last_performed_at
      t.datetime :perform_at
      t.boolean :deprecated, null: false, default: false
    end

    add_index :perform_every, [:job_name, :typ, :value], unique: true, name: "perform_every_unique_job"
    add_index :perform_every, :deprecated
  end
end
