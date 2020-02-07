# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_02_07_022209) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "perform_every", id: :serial, force: :cascade do |t|
    t.string "job_name"
    t.string "typ"
    t.string "value"
    t.string "history", array: true
    t.datetime "last_performed_at"
    t.datetime "perform_at"
    t.boolean "deprecated", default: false, null: false
    t.index ["job_name", "typ", "value"], name: "perform_every_unique_job", unique: true
  end
end
