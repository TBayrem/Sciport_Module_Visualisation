require "test_helper"

class ResearchProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @research_project = research_projects(:one)
  end

  test "should get index" do
    get research_projects_url
    assert_response :success
  end

  test "should get new" do
    get new_research_project_url
    assert_response :success
  end

  test "should create research_project" do
    assert_difference("ResearchProject.count") do
      post research_projects_url, params: { research_project: { description: @research_project.description, end_date: @research_project.end_date, funding_by: @research_project.funding_by, start_date: @research_project.start_date, title: @research_project.title } }
    end

    assert_redirected_to research_project_url(ResearchProject.last)
  end

  test "should show research_project" do
    get research_project_url(@research_project)
    assert_response :success
  end

  test "should get edit" do
    get edit_research_project_url(@research_project)
    assert_response :success
  end

  test "should update research_project" do
    patch research_project_url(@research_project), params: { research_project: { description: @research_project.description, end_date: @research_project.end_date, funding_by: @research_project.funding_by, start_date: @research_project.start_date, title: @research_project.title } }
    assert_redirected_to research_project_url(@research_project)
  end

  test "should destroy research_project" do
    assert_difference("ResearchProject.count", -1) do
      delete research_project_url(@research_project)
    end

    assert_redirected_to research_projects_url
  end
end
