# == Schema Information
#
# Table name: maintenance_updates
#
#  id             :integer          not null, primary key
#  identifier     :string
#  notify         :boolean          default(FALSE)
#  text           :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  maintenance_id :integer
#  user_id        :integer
#

class MaintenanceUpdate < ActiveRecord::Base

  belongs_to :maintenance, :touch => true
  belongs_to :user

  delegate :subscribers, to: :maintenance

  validates :text, :presence => true

  random_string :identifier, :type => :hex, :length => 6, :unique => true

  scope :ordered, -> { order(:id => :desc) }

  after_commit :send_notifications_on_create, :on => :create

  florrick do
    string :text
    string :identifier
    relationship :maintenance
    relationship :user
  end

  def send_notifications
    for subscriber in subscribers
      Staytus::Email.deliver(subscriber, :new_maintenance_update, :maintenance => self.maintenance, :update => self)
    end
  end

  def send_notifications_on_create
    if self.notify?
      self.send_notifications
    end
  end

end
