require_relative "../test_helper"

class SubscribeTest < ActionDispatch::IntegrationTest
  def teardown
    InvisibleCaptcha.timestamp_enabled = false
  end

  test "can subscribe by email" do
    visit '/'
    click_on 'Subscribe'
    assert_current_path '/subscribe'
    fill_in 'email_address', with: 'bob@example.com'
    click_on 'Subscribe'
    assert_css ".flashMessage", text: "Thanks - please check your email and click the link within to confirm your subscription."
    assert_current_path '/'
    subscriber = Subscriber.first
    assert_equal 'bob@example.com', subscriber.email_address
    assert_equal [], subscriber.service_ids
    assert_nil subscriber.verified_at
  end

  test "subscribe is rejected if too fast" do
    # time protection disabled in other tests by default
    InvisibleCaptcha.timestamp_enabled = true
    visit '/subscribe'
    fill_in 'email_address', with: 'bob@example.com'
    click_on 'Subscribe'
    assert_css ".flashMessage", text: "Sorry, that was too quick! Please resubmit."
    assert_current_path '/subscribe'
    assert_nil Subscriber.first
  end

  test "subscribe is quietly ignored if honeypot is filled" do
    visit '/subscribe'
    fill_in 'email_address', with: 'bob@example.com'
    fill_in 'name', with: 'Bob'
    click_on 'Subscribe'
    assert_current_path '/subscribe/email'
    assert_equal 200, page.status_code
    assert_equal "", page.body
    assert_nil Subscriber.first
  end
end