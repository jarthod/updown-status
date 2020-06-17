require_relative "../test_helper"

class PagesControllerTest < ActionController::TestCase
  test "supports json for index" do
    get :index, format: "json"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "updown.io status", body["site"]["title"]
    assert_equal "Simple and Inexpensive website monitoring", body["site"]["description"]
    assert_equal [], body["ongoing_issues"]
    assert_equal [], body["planned_maintenances"]
    assert_equal Service.count, body["services"].size
    assert_equal "Web Application", body["services"][0]["name"]
    assert_equal "web", body["services"][0]["permalink"]
    assert_equal "Web", body["services"][0]["group"]
    assert_equal "operational", body["services"][0]["status"]
    assert_equal ServiceStatus.count, body["services_statuses"].size
    assert_equal "Operational", body["services_statuses"][0]["name"]
    assert_equal "operational", body["services_statuses"][0]["permalink"]
    assert_equal "2FCC66", body["services_statuses"][0]["color"]
    assert_equal "ok", body["services_statuses"][0]["status_type"]
  end

  test "returns ongoing issues if any" do
    srv = services(:daemon_syd)
    i = Issue.create!(services: [srv], title: "ongoing issue", state: 'identified', service_status_id: 3, user: users(:adrien))
    get :index, format: "json"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["ongoing_issues"].size
    assert_equal i.identifier, body["ongoing_issues"][0]["identifier"]
    assert_equal "ongoing issue", body["ongoing_issues"][0]["title"]
    assert_equal "identified", body["ongoing_issues"][0]["state"]
    assert_equal [], body["planned_maintenances"]
    assert_equal "Sydney, Australia", body["services"][11]["name"]
    assert_equal "daemon-syd", body["services"][11]["permalink"]
    assert_equal "Monitoring", body["services"][11]["group"]
    assert_equal "partial-outage", body["services"][11]["status"]
  end

  test "returns planned maintenance if any" do
    srv = services(:custom_status_pages)
    i = Maintenance.create!(services: [srv], title: "moving server", description: "new datacenter", service_status_id: 5, start_at: 10.minutes.from_now, length_in_minutes: 60, user: users(:adrien))
    get :index, format: "json"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["planned_maintenances"].size
    assert_equal i.identifier, body["planned_maintenances"][0]["identifier"]
    assert_equal "moving server", body["planned_maintenances"][0]["title"]
    assert_equal "new datacenter", body["planned_maintenances"][0]["description"]
    assert_equal "upcoming", body["planned_maintenances"][0]["status"]
    assert_equal [], body["ongoing_issues"]
    assert_equal "Custom status pages", body["services"][2]["name"]
    assert_equal "custom-status-pages", body["services"][2]["permalink"]
    assert_equal "Web", body["services"][2]["group"]
    assert_equal "operational", body["services"][2]["status"]
  end
end