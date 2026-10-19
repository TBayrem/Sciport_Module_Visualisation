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

ActiveRecord::Schema[8.1].define(version: 2026_10_11_203805) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "authorships", force: :cascade do |t|
    t.bigint "publication_id", null: false
    t.integer "position"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.index ["publication_id"], name: "index_authorships_on_publication_id"
  end

  create_table "facilities", force: :cascade do |t|
    t.string "name"
    t.string "facility_type"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.index ["external_id"], name: "index_facilities_on_external_id", unique: true
    t.index ["parent_id"], name: "index_facilities_on_parent_id"
  end

  create_table "facilities_publications", id: false, force: :cascade do |t|
    t.bigint "facility_id", null: false
    t.bigint "publication_id", null: false
    t.index ["facility_id", "publication_id"], name: "idx_on_facility_id_publication_id_fab22b5353", unique: true
    t.index ["publication_id", "facility_id"], name: "idx_on_publication_id_facility_id_7acbbf9165"
  end

  create_table "facilities_research_projects", id: false, force: :cascade do |t|
    t.bigint "facility_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["facility_id", "research_project_id"], name: "idx_on_facility_id_research_project_id_0add79ce8e", unique: true
    t.index ["research_project_id", "facility_id"], name: "idx_on_research_project_id_facility_id_9bee2d146e"
  end

  create_table "people", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.text "field_of_research"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.index ["external_id"], name: "index_people_on_external_id", unique: true
  end

  create_table "people_publications", id: false, force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "publication_id", null: false
    t.index ["person_id", "publication_id"], name: "index_people_publications_on_person_id_and_publication_id", unique: true
    t.index ["publication_id", "person_id"], name: "index_people_publications_on_publication_id_and_person_id"
  end

  create_table "people_research_projects", id: false, force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["person_id", "research_project_id"], name: "idx_on_person_id_research_project_id_359c4c1456"
    t.index ["research_project_id", "person_id"], name: "idx_on_research_project_id_person_id_8616951a12"
  end

  create_table "publications", force: :cascade do |t|
    t.string "title"
    t.text "abstract"
    t.integer "publication_year"
    t.string "doi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "publications_research_projects", id: false, force: :cascade do |t|
    t.bigint "publication_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["publication_id", "research_project_id"], name: "idx_on_publication_id_research_project_id_4b8a358c8b", unique: true
    t.index ["research_project_id", "publication_id"], name: "idx_on_research_project_id_publication_id_3a20b1c486"
  end

  create_table "research_projects", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.text "keywords"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "facility_id", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["facility_id"], name: "index_roles_on_facility_id"
    t.index ["person_id"], name: "index_roles_on_person_id"
  end

  add_foreign_key "authorships", "publications"
  add_foreign_key "facilities", "facilities", column: "parent_id"
  add_foreign_key "facilities_publications", "facilities"
  add_foreign_key "facilities_publications", "publications"
  add_foreign_key "facilities_research_projects", "facilities"
  add_foreign_key "facilities_research_projects", "research_projects"
  add_foreign_key "publications_research_projects", "publications"
  add_foreign_key "publications_research_projects", "research_projects"
  add_foreign_key "roles", "facilities"
  add_foreign_key "roles", "people"
end
