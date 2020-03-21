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
    click_on 'Create Issue'
    assert_css ".flashMessage", text: "Issue has been added successfully."
    assert_content "Description Test issue"
    assert_content "State Investigating"
    fill_in 'issue_update_text', with: "Test update"
    click_on 'Post Update'
    assert_css ".flashMessage", text: "Update has been posted successfully."
  end
end
