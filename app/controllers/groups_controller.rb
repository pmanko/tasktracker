# frozen_string_literal: true

# Defines a group of tasks that were created together.
class GroupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_viewable_project, only: [:index]
  before_action :set_viewable_group, only: [:show]
  before_action :set_editable_group, only: [:edit, :update, :destroy]
  before_action :redirect_without_group, only: [:show, :edit, :update, :destroy]

  # GET /groups
  def index
    @order = scrub_order(Group, params[:order], 'groups.id DESC')
    @groups = current_user.all_viewable_groups.search(params[:search]).filter(params)
                          .order(@order).page(params[:page]).per(40)
  end

  # GET /groups/1
  def show
  end

  # GET /groups/new
  def new
    @group = current_user.groups.new(group_params)
    @group.project = current_user.all_projects.first if !@group.project && current_user.all_projects.size == 1
    @group.template = @group.project.templates.first if @group.project && @group.project.templates.size == 1

    respond_to do |format|
      format.js
      format.html { redirect_to groups_path }
    end
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  # POST /groups.js
  def create
    g_params = group_params

    @template = current_user.all_templates.find_by_id(params[:group][:template_id]) if params[:group]

    if @template
      @group = @template.generate_stickies!(current_user, g_params[:board_id], g_params[:initial_due_date], g_params[:description])
      respond_to do |format|
        format.html { redirect_to @group, notice: @group.stickies.size.to_s + ' ' + ((@group.stickies.size == 1) ? 'sticky' : 'stickies') + " successfully created and added to #{(@board ? @board.name : 'Holding Pen')}." }
        format.js { render :create }
      end
    else
      respond_to do |format|
        format.html { redirect_to groups_path }
        format.js { render :new }
      end
    end
  end

  # PATCH /groups/1
  def update
    if @group.update(group_params)
      redirect_to @group, notice: 'Group was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /groups/1
  def destroy
    @group.destroy
    redirect_to groups_path
  end

  private

  def set_viewable_group
    @group = current_user.all_viewable_groups.find_by_id(params[:id])
  end

  def set_editable_group
    @group = current_user.all_groups.find_by_id(params[:id])
  end

  def redirect_without_group
    empty_response_or_root_path(groups_path) unless @group
  end

  def group_params
    params[:group] ||= { blank: '1' } # {}

    unless params[:group][:project_id].blank?
      project = current_user.all_projects.find_by_id(params[:group][:project_id])
      params[:group][:project_id] = project ? project.id : nil
    end

    if project && params[:create_new_board] == '1'
      if params[:group_board_name].to_s.strip.blank?
        params[:group][:board_id] = nil
      else
        @board = project.boards.where(name: params[:group_board_name].to_s.strip).first_or_create( user_id: current_user.id )
        params[:group][:board_id] = @board.id
      end
    elsif project
      @board = project.boards.find_by_id(params[:group][:board_id])
    end

    params[:group][:board_id] = (@board ? @board.id : nil)

    [:initial_due_date].each do |date|
      params[:group][date] = parse_date(params[:group][date], Date.today)
    end

    params.require(:group).permit(
      :description, :project_id, :board_id, :template_id, :initial_due_date
    )
  end
end
