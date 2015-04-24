class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :encryptable, :confirmable, :lockable and :omniauthable
  devise :database_authenticatable, :registerable, :timeoutable,
         :recoverable, :rememberable, :trackable, :validatable

  before_create :set_default_calendar_options
  after_create :notify_system_admins

  STATUS = ["active", "denied", "inactive", "pending"].collect{|i| [i,i]}

  EMAILABLES = [ [:sticky_creation, 'Receive email when a new task is created'],
                 [:sticky_completion, 'Receive email when a task is marked as completed'],
                 # [:sticky_due_time_changed, 'Receive email when a task\'s due date time is changed'],
                 [:sticky_comments, 'Receive email when a comment is added to a task'],
                 [:daily_stickies_due, 'Receive daily weekday emails if there are tasks due or past due'],
                 [:daily_digest, 'Receive daily digest emails of tasks that have been created and completed the previous day'] ]

  serialize :colors, Hash
  serialize :email_notifications, Hash
  serialize :hidden_project_ids, Array
  serialize :settings, Hash
  serialize :sticky_filters, Hash

  # Concerns
  include Deletable

  # Named Scopes
  scope :status, lambda { |arg|  where( status: arg ) }
  scope :search, lambda { |arg| where( 'LOWER(first_name) LIKE ? or LOWER(last_name) LIKE ? or LOWER(email) LIKE ?', arg.to_s.downcase.gsub(/^| |$/, '%'), arg.to_s.downcase.gsub(/^| |$/, '%'), arg.to_s.downcase.gsub(/^| |$/, '%') ) }
  scope :system_admins, -> { where system_admin: true }
  scope :with_project, lambda { |*args| where( "users.id in (select projects.user_id from projects where projects.id IN (?) and projects.deleted = ?) or users.id in (select project_users.user_id from project_users where project_users.project_id IN (?) and project_users.allow_editing IN (?))", args.first, false, args.first, args[1] ) }
  scope :with_name, lambda { |arg| where("(users.first_name || ' ' || users.last_name) IN (?)", arg) }

  # Model Validation
  validates_presence_of     :first_name
  validates_presence_of     :last_name

  # Model Relationships
  has_many :projects, -> { where( deleted: false ).order( 'name' ) }
  has_many :project_favorites
  has_many :boards, -> { where deleted: false }
  has_many :groups, -> { where deleted: false }
  has_many :tags, -> { where deleted: false }
  has_many :templates, -> { where( deleted: false ).order( 'created_at' ) }
  has_many :stickies, -> { where( deleted: false ).order( 'created_at' ) }
  has_many :comments, -> { where( deleted: false ).order( 'created_at DESC' ) }

  has_many :owned_stickies, -> { where( deleted: false ).order( 'created_at' ) }, class_name: 'Sticky', foreign_key: 'owner_id'

  # User Methods

  def avatar_url(size = 80, default = 'mm')
    gravatar_id = Digest::MD5.hexdigest(self.email.to_s.downcase)
    "//gravatar.com/avatar/#{gravatar_id}.png?&s=#{size}&r=pg&d=#{default}"
  end

  def associated_users
    User.where( deleted: false ).with_project(self.all_viewable_projects.pluck(:id), [true, false])
  end

  def associated_users_assigned_tasks
    User.where( deleted: false, id: Sticky.where( owner_id: associated_users.pluck(:id), project_id: self.all_viewable_projects.pluck(:id) ).pluck(:owner_id) )
  end

  def update_sticky_filters!(sticky_filter_hash = {})
    self.update_attributes sticky_filters: sticky_filter_hash
  end

  # Overriding Devise built-in active_for_authentication? method
  def active_for_authentication?
    super and self.status == 'active' and not self.deleted?
  end

  def destroy
    super
    update_column :status, 'inactive'
    update_column :updated_at, Time.now
  end

  def email_on?(value)
    self.active_for_authentication? and [nil, true].include?(self.email_notifications[value.to_s])
  end

  def all_projects
    @all_projects ||= begin
      Project.current.with_user(self.id, true) #.order('name')
    end
  end

  def all_viewable_projects
    @all_viewable_projects ||= begin
      Project.current.with_user(self.id, [true, false]) #.order('name')
    end
  end

  def all_favorite_projects
    @all_favorite_projects ||= begin
      self.all_projects.by_favorite(self.id).where("project_favorites.favorite = ?", true).order('name')
    end
  end

  def all_other_projects
    @all_other_projects ||= begin
      self.all_projects.where("projects.id NOT IN (?)", [0] + self.all_favorite_projects.pluck("projects.id")).order('name')
    end
  end

  def all_stickies
    @all_stickies ||= begin
      Sticky.current.where(project_id: self.all_projects.pluck(:id)).order('created_at DESC')
    end
  end

  def all_stickies_due_today
    self.all_stickies.due_today.with_owner(self.id)
  end

  def all_stickies_past_due
    self.all_stickies.past_due.with_owner(self.id)
  end

  def all_stickies_due_upcoming
    self.all_stickies.due_upcoming.with_owner(self.id)
  end

  def all_deliverable_projects
    @all_deliverable_projects ||= begin
      self.all_projects.select{|p| self.email_on?(:send_email) and self.email_on?(:daily_stickies_due) and self.email_on?("project_#{p.id}") and self.email_on?("project_#{p.id}_daily_stickies_due") }
    end
  end

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
    @all_digest_projects ||= begin
      self.all_projects.select{|p| self.email_on?(:send_email) and self.email_on?(:daily_digest) and self.email_on?("project_#{p.id}") and self.email_on?("project_#{p.id}_daily_digest") }
    end
  end

  # All tasks created in the last day, or over the weekend if it's Monday
  # Ex: On Monday, returns tasks created since Friday morning (Time.now - 3.day)
  # Ex: On Tuesday, returns tasks created since Monday morning (Time.now - 1.day)
  def digest_stickies_created
    @digest_stickies_created ||= begin
      self.all_stickies.where(project_id: self.all_digest_projects.collect{|p| p.id}, completed: false).where("created_at > ?", (Time.now.monday? ? Time.now - 3.day : Time.now - 1.day))
    end
  end

  def digest_stickies_completed
    @digest_stickies_completed ||= begin
      self.all_stickies.where(project_id: self.all_digest_projects.collect{|p| p.id}).where("end_date >= ?", (Date.today.monday? ? Date.today - 3.day : Date.today - 1.day))
    end
  end

  def digest_comments
    @digest_comments ||= begin
      self.all_viewable_comments.with_project(self.all_digest_projects.collect{|p| p.id}).where("created_at > ?", (Time.now.monday? ? Time.now - 3.day : Time.now - 1.day)).order('created_at ASC')
    end
  end

  def all_viewable_stickies
    @all_viewable_stickies ||= begin
      Sticky.current.where(project_id: self.all_viewable_projects.pluck(:id))
    end
  end

  def all_groups
    @all_groups ||= begin
      Group.current.where(project_id: self.all_projects.pluck(:id))
    end
  end

  def all_viewable_groups
    @all_viewable_groups ||= begin
      Group.current.where(project_id: self.all_viewable_projects.pluck(:id))
    end
  end

  def all_boards
    @all_boards ||= begin
      Board.current.where(project_id: self.all_projects.pluck(:id))
    end
  end

  def all_viewable_boards
    @all_viewable_boards ||= begin
      Board.current.where(project_id: self.all_viewable_projects.pluck(:id))
    end
  end

  def all_tags
    @all_tags ||= begin
      Tag.current.where(project_id: self.all_projects.pluck(:id))
    end
  end

  def all_viewable_tags
    @all_viewable_tags ||= begin
      Tag.current.where(project_id: self.all_viewable_projects.pluck(:id))
    end
  end

  def all_templates
    @all_templates ||= begin
      Template.current.where(project_id: self.all_projects.pluck(:id))
    end
  end

  def all_viewable_templates
    @all_viewable_templates ||= begin
      Template.current.where(project_id: self.all_viewable_projects.pluck(:id))
    end
  end

  def all_comments
    @all_comments ||= begin
      self.comments
    end
  end

  def all_viewable_comments
    @all_viewable_comments ||= begin
      Comment.current.where(sticky_id: self.all_viewable_stickies.pluck(:id))
    end
  end

  def all_deletable_comments
    @all_deletable_comments ||= begin
      Comment.current.where("sticky_id IN (?) or user_id = ?", self.all_stickies.pluck(:id), self.id)
    end
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

  private

  def set_default_calendar_options
    self.settings = { calendar_status: ['planned', 'completed'] }
  end

  def notify_system_admins
    User.current.system_admins.each do |system_admin|
      UserMailer.notify_system_admin(system_admin, self).deliver_later if Rails.env.production?
    end
  end
end
