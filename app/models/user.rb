# frozen_string_literal: true

# The user class provides methods to scope resources in system that the user is
# allowed to view and edit.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :encryptable, :confirmable, :lockable and :omniauthable
  devise :database_authenticatable, :timeoutable, # , :registerable
         :recoverable, :rememberable, :trackable, :validatable

  # TODO: Remove emailables
  EMAILABLES = [ [:sticky_creation, 'Receive email when a new task is created'],
                 [:sticky_completion, 'Receive email when a task is marked as completed'],
                 # [:sticky_due_time_changed, 'Receive email when a task\'s due date time is changed'],
                 [:sticky_comments, 'Receive email when a comment is added to a task'],
                 [:daily_stickies_due, 'Receive daily weekday emails if there are tasks due or past due'],
                 [:daily_digest, 'Receive daily digest emails of tasks that have been created and completed the previous day'] ]
  # END TODO
  CALENDAR_VIEW = [['Month View', 'month'], ['4 Week View', '4week']]

  # Concerns
  include Deletable, Searchable

  # Scopes
  scope :with_project, -> (*args) { where( "users.id in (select projects.user_id from projects where projects.id IN (?) and projects.deleted = ?) or users.id in (select project_users.user_id from project_users where project_users.project_id IN (?) and project_users.allow_editing IN (?))", args.first, false, args.first, args[1] ) }
  scope :with_name, -> (arg) { where("(users.first_name || ' ' || users.last_name) IN (?)", arg) }

  # Model Validation
  validates :first_name, :last_name, presence: true

  # Model Relationships
  has_many :comments, -> { current.order(created_at: :desc) }
  has_many :projects, -> { current.order(:name) }
  has_many :project_users
  has_many :project_preferences
  has_many :boards, -> { current }
  has_many :groups, -> { current }
  has_many :notifications, -> { joins(:project).merge(Project.current) }
  has_many :tags, -> { current }
  has_many :templates, -> { current.order(:created_at) }
  has_many :stickies, -> { current.order(:created_at) }
  has_many :owned_stickies, -> { current.order(:created_at) }, class_name: 'Sticky', foreign_key: 'owner_id'
  has_many :project_filters
  has_many :tag_filters
  has_many :owner_filters

  # User Methods

  def self.searchable_attributes
    %w(first_name last_name email)
  end

  def avatar_url(size = 80, default = 'mm')
    gravatar_id = Digest::MD5.hexdigest(self.email.to_s.downcase)
    "//gravatar.com/avatar/#{gravatar_id}.png?&s=#{size}&r=pg&d=#{default}"
  end

  def associated_users
    project_ids = all_viewable_projects.select(:id)
    User.joins('LEFT OUTER JOIN project_users ON project_users.user_id = users.id')
        .joins('LEFT OUTER JOIN projects ON projects.user_id = users.id')
        .where('project_users.project_id IN (?) or projects.id IN (?)', project_ids, project_ids)
        .distinct
  end

  def associated_users_assigned_tasks
    User.current.where(id: Sticky.where(owner_id: associated_users.select(:id), project_id: all_viewable_non_archived_projects.select(:id)).select(:owner_id))
  end

  # Overriding Devise built-in active_for_authentication? method
  def active_for_authentication?
    super && !deleted?
  end

  def unread_notifications?
    notifications.where(read: false).count > 0
  end

  def destroy
    super
    update_column :updated_at, Time.zone.now
  end

  def all_projects
    Project
      .current
      .joins("LEFT OUTER JOIN project_users ON project_users.project_id = projects.id and project_users.user_id = #{id}")
      .where('projects.user_id = ? or project_users.allow_editing = ?', id, true)
  end

  def all_non_archived_projects
    all_projects.where.not(id: project_preferences.where(archived: true).select(:project_id))
  end

  def all_viewable_projects
    Project
      .current
      .joins("LEFT OUTER JOIN project_users ON project_users.project_id = projects.id and project_users.user_id = #{id}")
      .where('projects.user_id = ? or project_users.user_id = ?', id, id)
  end

  def all_viewable_non_archived_projects
    all_viewable_projects.where.not(id: project_preferences.where(archived: true).select(:project_id))
  end

  def all_stickies
    Sticky.current.where(project_id: all_projects.select(:id)).order(created_at: :desc)
  end

  def all_stickies_due_today
    all_stickies.due_today.with_owner(id)
  end

  def all_stickies_past_due
    all_stickies.past_due.with_owner(id)
  end

  def all_stickies_due_upcoming
    all_stickies.due_upcoming.with_owner(id)
  end

  # TODO: Remove in 0.30.0
  def all_deliverable_projects
    all_digest_projects
  end
  # END TODO

  def all_deliverable_stickies_due_today
    self.all_stickies_due_today.where(project_id: self.all_deliverable_projects.collect{|p| p.id})
  end

  def all_deliverable_stickies_past_due
    self.all_stickies_past_due.where(project_id: self.all_deliverable_projects.collect{|p| p.id})
  end

  def all_deliverable_stickies_due_upcoming
    self.all_stickies_due_upcoming.where(project_id: self.all_deliverable_projects.collect{|p| p.id})
  end

  def all_digest_projects
    return Project.none unless emails_enabled?
    all_viewable_projects
      .joins("LEFT OUTER JOIN project_preferences ON project_preferences.project_id = projects.id and project_preferences.user_id = #{id}")
      .where('project_preferences.emails_enabled IS NULL or project_preferences.emails_enabled = ?', true)
  end

  # All tasks created in the last day, or over the weekend if it's Monday
  # Ex: On Monday, returns tasks created since Friday morning (Time.zone.now - 3.day)
  # Ex: On Tuesday, returns tasks created since Monday morning (Time.zone.now - 1.day)
  def digest_stickies_created
    all_stickies.where(project_id: all_digest_projects.select(:id), completed: false).where('created_at > ?', (Time.zone.now.monday? ? Time.zone.now - 3.day : Time.zone.now - 1.day))
  end

  def digest_stickies_completed
    all_stickies.where(project_id: all_digest_projects.select(:id)).where('end_date >= ?', (Date.today.monday? ? Date.today - 3.day : Date.today - 1.day))
  end

  def digest_comments
    all_viewable_comments.with_project(all_digest_projects.select(:id)).where('created_at > ?', (Time.zone.now.monday? ? Time.zone.now - 3.day : Time.zone.now - 1.day)).order(:created_at)
  end

  def all_viewable_stickies
    Sticky.current.where(project_id: all_viewable_projects.select(:id))
  end

  def all_groups
    Group.current.where(project_id: all_projects.select(:id))
  end

  def all_viewable_groups
    Group.current.where(project_id: all_viewable_projects.select(:id))
  end

  def all_boards
    Board.current.where(project_id: all_projects.select(:id))
  end

  def all_viewable_boards
    Board.current.where(project_id: all_viewable_projects.select(:id))
  end

  def all_tags
    Tag.current.where(project_id: all_projects.select(:id))
  end

  def all_viewable_tags
    Tag.current.where(project_id: all_viewable_projects.select(:id))
  end

  def all_templates
    Template.current.where(project_id: all_projects.select(:id))
  end

  def all_viewable_templates
    Template.current.where(project_id: all_viewable_projects.select(:id))
  end

  def all_comments
    comments
  end

  def all_viewable_comments
    Comment.current.where(sticky_id: all_viewable_stickies.select(:id))
  end

  def all_deletable_comments
    Comment.current.where('sticky_id IN (?) or user_id = ?', all_stickies.select(:id), id)
  end

  def name
    "#{first_name} #{last_name}"
  end

  def reverse_name
    "#{last_name}, #{first_name}"
  end

  def nickname
    "#{first_name} #{last_name.first}"
  end
end
