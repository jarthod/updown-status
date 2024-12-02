require_relative "../test_helper"

class AdminTest < ActionDispatch::IntegrationTest
  def login
    visit '/admin'
    assert_current_path '/admin/login'
    fill_in 'E-Mail Address', with: users(:adrien).email_address
    fill_in 'Password', with: 'password'
    click_on 'Login'
    assert_current_path '/admin'
  end

  test "can login as admin" do
    visit '/admin'
    assert_current_path '/admin/login'
    fill_in 'E-Mail Address', with: users(:adrien).email_address
    fill_in 'Password', with: 'password'
    click_on 'Login'
    assert_current_path '/admin'
  end

  test "can create an issue" do
    login
    click_on 'Issues'
    assert_current_path '/admin/issues'
    click_on 'Post a new issue'
    assert_current_path '/admin/issues/new'
    fill_in 'Title', with: "Test issue"
    check 'Los Angeles, US'
    check 'API'
    select 'Major Outage'
    assert_equal 0, HistoryItem.count
    click_on 'Create Issue'
    assert_equal 1, HistoryItem.count
    assert_css ".flashMessage", text: "Issue has been added successfully."
    assert_content "Description Test issue"
    assert_content "State Investigating"
    assert_equal 4, services(:daemon_lan).status_id
    assert_equal 4, services(:api).status_id
    assert_equal 1, services(:web).status_id
    Capybara.using_session('visitor') do
      visit '/'
      assert_content 'Test issue'
      assert_css 'span.serviceStatusTag', text: "Major Outage", count: 2
    end
    # Post update
    fill_in 'issue_update_text', with: "Found"
    choose "Investigating"
    select 'Degraded Performance'
    click_on 'Post Update'
    assert_css ".flashMessage", text: "Update has been posted successfully."
    assert_equal 2, services(:daemon_lan).reload.status_id
    assert_equal 2, services(:api).reload.status_id
    assert_content "State Investigating"
    Capybara.using_session('visitor') do
      visit '/'
      assert_content 'Test issue'
      assert_css 'span.serviceStatusTag', text: "Degraded Performance", count: 2
    end
    # Closing
    fill_in 'issue_update_text', with: "Fixed"
    choose "Resolved"
    select 'Operational'
    click_on 'Post Update'
    assert_css ".flashMessage", text: "Update has been posted successfully."
    assert_equal 1, services(:daemon_lan).reload.status_id
    assert_equal 1, services(:api).reload.status_id
    assert_content "State Resolved"
    Capybara.using_session('visitor') do
      visit '/'
      assert_no_content 'Test issue'
      assert_css 'span.serviceStatusTag', text: "Operational", count: Service.count
    end
    assert_equal 1, HistoryItem.count
  end

  test "can create an maintenance" do
    login
    click_on 'Maintenance'
    assert_current_path '/admin/maintenances'
    click_on 'New Session'
    assert_current_path '/admin/maintenances/new'
    fill_in 'Title', with: "Test maintenance"
    fill_in 'Description', with: "Test maintenance"
    fill_in 'Start time', with: "2020-03-30 3pm"
    fill_in 'How long will this session last?', with: "1h"
    check 'Los Angeles, US'
    check 'API'
    assert_equal 0, HistoryItem.count
    click_on 'Create Maintenance'
    assert_equal 1, HistoryItem.count
    assert_css ".flashMessage", text: "Maintenance session has been added successfully."
    assert_content "Test maintenance"
    assert_content "In Progress"
    Capybara.using_session('visitor') do
      visit '/'
      assert_content 'Test maintenance'
      assert_css 'span.serviceStatusTag', text: "Maintenance", count: 2
    end
    # Updating components
    click_on "Test maintenance"
    click_on "Edit Details"
    fill_in 'Description', with: "Test maintenance also with web"
    check 'Web'
    click_on 'Update Maintenance'
    assert_css ".flashMessage", text: "Maintenance session has been updated successfully."
    Capybara.using_session('visitor') do
      visit '/'
      assert_content 'Test maintenance'
      assert_css 'span.serviceStatusTag', text: "Maintenance", count: 3
    end
    # Post an update
    fill_in 'Post an update', with: "Oops we're late, sorry"
    click_on 'Post Update'
    assert_css ".flashMessage", text: "Update has been posted successfully."
    assert_content "Oops we're late, sorry"
    # Closing
    click_on "Finish Session"
    assert_css ".flashMessage", text: "Maintenance session has been finished successfully."
    Capybara.using_session('visitor') do
      visit '/'
      assert_no_content 'maintenance'
      assert_css 'span.serviceStatusTag', text: "Operational", count: Service.count
    end
    assert_equal 1, HistoryItem.count
  end

  test "can manage subscribers" do
    login
    click_on 'Subscribers'
    assert_current_path '/admin/subscribers'
    # Create
    click_on 'Add a new subscriber'
    assert_current_path '/admin/subscribers/new'
    fill_in 'subscriber_email_address', with: "bob@example.com"
    click_on 'Create Subscriber'
    assert_css ".flashMessage", text: "Subscriber has been created"
    assert_css "td", text: "bob@example.com"
    Subscriber.update_all(verified_at: nil) # mark as not verified
    click_on 'Add a new subscriber'
    fill_in 'subscriber_email_address', with: "alice@example.com"
    click_on 'Create Subscriber'
    assert_css ".flashMessage", text: "Subscriber has been created"
    # Verify
    click_on 'Verify'
    assert_css ".flashMessage", text: "bob@example.com has been verified successfully"
    # Clean
    Subscriber.first.update(created_at: 1.week.ago) # Bob: old and verified, should not be removed
    alice = Subscriber.last
    alice.update(verified_at: nil) # not verified but recent, should not be removed (likely to verify)
    click_on 'Clean unverified subscribers'
    assert_css ".flashMessage", text: "0 unverified subscribers have been removed successfully"
    assert_css "td", text: "bob@example.com" # bob is still here
    assert_css "td", text: "alice@example.com" # alice too
    # 2 days later alice can be removed
    alice.update(created_at: 2.days.ago)
    click_on 'Clean unverified subscribers'
    assert_css ".flashMessage", text: "1 unverified subscribers have been removed successfully"
    assert_css "td", text: "bob@example.com" # bob is still here
    assert_no_css "td", text: "alice@example.com" # alice is gone
    # Delete (single)
    click_on "X"
    assert_css ".flashMessage", text: "bob@example.com has been removed successfully"
    assert_no_css "td", text: "bob@example.com" # bob is gone
  end

  test "can update settings" do
    login
    click_on 'Settings'
    assert_current_path '/admin/settings'
    click_on 'General Settings'
    assert_current_path '/admin/settings/general'
    fill_in 'Title', with: "Site name"
    uncheck 'Yes - allow search engines to index the public status site'
    select '(GMT-09:00) Alaska'
    click_on 'Save Settings'
    assert_css ".flashMessage", text: "Settings have been saved successfully."
    site = Site.first
    assert_equal "Site name", site.title
    assert_equal false, site.crawling_permitted
    assert_equal "Alaska", site.time_zone
  end
end
