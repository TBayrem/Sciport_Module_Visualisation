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

ActiveRecord::Schema[8.1].define(version: 2026_11_09_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_cluster_assignments", force: :cascade do |t|
    t.bigint "clustering_id", null: false
    t.bigint "person_id", null: false
    t.integer "cluster_number", null: false
    t.index ["clustering_id", "person_id"], name: "index_analysis_cluster_assignments_unique", unique: true
  end

  create_table "analysis_clusterings", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.string "algorithm", null: false
    t.integer "k"
    t.float "eps"
    t.integer "min_pts"
    t.integer "cluster_count", default: 0, null: false
    t.integer "noise_count", default: 0, null: false
    t.index ["run_id", "algorithm", "k", "eps", "min_pts"], name: "index_analysis_clusterings_unique", unique: true
    t.check_constraint "algorithm::text = 'kmeans'::text AND k IS NOT NULL OR algorithm::text = 'dbscan'::text AND eps IS NOT NULL AND min_pts IS NOT NULL", name: "analysis_clusterings_params_check"
    t.check_constraint "algorithm::text = ANY (ARRAY['kmeans'::character varying, 'dbscan'::character varying]::text[])", name: "analysis_clusterings_algorithm_check"
  end

  create_table "analysis_projections", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.bigint "person_id", null: false
    t.string "projection_method", null: false
    t.float "x", null: false
    t.float "y", null: false
    t.index ["run_id", "projection_method", "person_id"], name: "index_analysis_projections_unique", unique: true
    t.check_constraint "projection_method::text = ANY (ARRAY['pca'::character varying, 'tsne'::character varying, 'umap'::character varying]::text[])", name: "analysis_projections_method_check"
  end

  create_table "analysis_runs", force: :cascade do |t|
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.string "status", default: "running", null: false
    t.index ["status", "finished_at"], name: "index_analysis_runs_on_status_and_finished_at"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'finished'::character varying, 'failed'::character varying]::text[])", name: "analysis_runs_status_check"
  end

  create_table "analysis_similarities", force: :cascade do |t|
    t.bigint "run_id", null: false
    t.bigint "person_a_id", null: false
    t.bigint "person_b_id", null: false
    t.float "score", null: false
    t.index ["run_id", "person_a_id", "person_b_id"], name: "index_analysis_similarities_unique", unique: true
    t.index ["run_id", "score"], name: "index_analysis_similarities_on_run_id_and_score"
    t.check_constraint "person_a_id < person_b_id", name: "analysis_similarities_pair_order_check"
    t.check_constraint "score >= 0::double precision AND score <= 1::double precision", name: "analysis_similarities_score_check"
  end

  create_table "analysis_topics", force: :cascade do |t|
    t.bigint "clustering_id", null: false
    t.integer "cluster_number", null: false
    t.string "terms", default: [], null: false, array: true
    t.index ["clustering_id", "cluster_number"], name: "index_analysis_topics_unique", unique: true
  end

  create_table "authorships", force: :cascade do |t|
    t.bigint "publication_id", null: false
    t.string "first_name"
    t.string "last_name", null: false
    t.integer "position"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_id", "position"], name: "index_authorships_on_publication_id_and_position", unique: true
  end

  create_table "facilities", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "facility_type"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_facilities_on_external_id", unique: true
    t.index ["parent_id"], name: "index_facilities_on_parent_id"
  end

  create_table "facilities_publications", id: false, force: :cascade do |t|
    t.bigint "facility_id", null: false
    t.bigint "publication_id", null: false
    t.index ["facility_id", "publication_id"], name: "index_facilities_publications_unique", unique: true
    t.index ["publication_id"], name: "index_facilities_publications_on_publication_id"
  end

  create_table "facilities_research_projects", id: false, force: :cascade do |t|
    t.bigint "facility_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["facility_id", "research_project_id"], name: "index_facilities_research_projects_unique", unique: true
    t.index ["research_project_id"], name: "index_facilities_research_projects_on_research_project_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "title"
    t.text "field_of_research"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_people_on_external_id", unique: true
    t.index ["last_name", "first_name"], name: "index_people_on_last_name_and_first_name"
  end

  create_table "people_publications", id: false, force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "publication_id", null: false
    t.index ["person_id", "publication_id"], name: "index_people_publications_unique", unique: true
    t.index ["publication_id"], name: "index_people_publications_on_publication_id"
  end

  create_table "people_research_projects", id: false, force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["person_id", "research_project_id"], name: "index_people_research_projects_unique", unique: true
    t.index ["research_project_id"], name: "index_people_research_projects_on_research_project_id"
  end

  create_table "publications", force: :cascade do |t|
    t.string "external_id"
    t.string "title", null: false
    t.text "abstract"
    t.integer "publication_year"
    t.string "doi"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_publications_on_external_id", unique: true
    t.index ["publication_year"], name: "index_publications_on_publication_year"
  end

  create_table "publications_research_projects", id: false, force: :cascade do |t|
    t.bigint "publication_id", null: false
    t.bigint "research_project_id", null: false
    t.index ["publication_id", "research_project_id"], name: "index_publications_research_projects_unique", unique: true
    t.index ["research_project_id"], name: "index_publications_research_projects_on_research_project_id"
  end

  create_table "research_projects", force: :cascade do |t|
    t.string "external_id"
    t.string "title", null: false
    t.text "description"
    t.text "keywords"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_research_projects_on_external_id", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "facility_id", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["facility_id"], name: "index_roles_on_facility_id"
    t.index ["person_id", "facility_id", "description"], name: "index_roles_on_person_facility_description", unique: true
  end

  add_foreign_key "analysis_cluster_assignments", "analysis_clusterings", column: "clustering_id", on_delete: :cascade
  add_foreign_key "analysis_clusterings", "analysis_runs", column: "run_id", on_delete: :cascade
  add_foreign_key "analysis_projections", "analysis_runs", column: "run_id", on_delete: :cascade
  add_foreign_key "analysis_similarities", "analysis_runs", column: "run_id", on_delete: :cascade
  add_foreign_key "analysis_topics", "analysis_clusterings", column: "clustering_id", on_delete: :cascade
  add_foreign_key "authorships", "publications", on_delete: :cascade
  add_foreign_key "facilities", "facilities", column: "parent_id", on_delete: :nullify
  add_foreign_key "facilities_publications", "facilities", on_delete: :cascade
  add_foreign_key "facilities_publications", "publications", on_delete: :cascade
  add_foreign_key "facilities_research_projects", "facilities", on_delete: :cascade
  add_foreign_key "facilities_research_projects", "research_projects", on_delete: :cascade
  add_foreign_key "people_publications", "people", on_delete: :cascade
  add_foreign_key "people_publications", "publications", on_delete: :cascade
  add_foreign_key "people_research_projects", "people", on_delete: :cascade
  add_foreign_key "people_research_projects", "research_projects", on_delete: :cascade
  add_foreign_key "publications_research_projects", "publications", on_delete: :cascade
  add_foreign_key "publications_research_projects", "research_projects", on_delete: :cascade
  add_foreign_key "roles", "facilities", on_delete: :cascade
  add_foreign_key "roles", "people", on_delete: :cascade
end
