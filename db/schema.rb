# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_27_162507) do
  create_table "facilities", force: :cascade do |t|
    t.string "api_id"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "facility_type"
    t.string "name"
    t.string "phone_number"
    t.string "street"
    t.datetime "updated_at", null: false
    t.string "website"
    t.string "zip_code"
  end

  create_table "facilities_people", id: false, force: :cascade do |t|
    t.integer "facility_id", null: false
    t.integer "person_id", null: false
  end

  create_table "facilities_publications", id: false, force: :cascade do |t|
    t.integer "facility_id", null: false
    t.integer "publication_id", null: false
  end

  create_table "facilities_research_projects", id: false, force: :cascade do |t|
    t.integer "facility_id", null: false
    t.integer "research_project_id", null: false
  end

  create_table "patents", force: :cascade do |t|
    t.string "api_id"
    t.datetime "created_at", null: false
    t.string "holder"
    t.string "number"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "patents_people", id: false, force: :cascade do |t|
    t.integer "patent_id", null: false
    t.integer "person_id", null: false
  end

  create_table "people", force: :cascade do |t|
    t.string "api_id"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "people_publications", id: false, force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "publication_id", null: false
  end

  create_table "people_research_projects", id: false, force: :cascade do |t|
    t.integer "person_id", null: false
    t.integer "research_project_id", null: false
  end

  create_table "publications", force: :cascade do |t|
    t.string "api_id"
    t.string "authors"
    t.datetime "created_at", null: false
    t.string "publication_type"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "year_of_publication"
  end

  create_table "publications_research_projects", id: false, force: :cascade do |t|
    t.integer "publication_id", null: false
    t.integer "research_project_id", null: false
  end

  create_table "research_projects", force: :cascade do |t|
    t.string "api_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.string "funding_by"
    t.date "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end
end
