class IncidentResponseController < ApplicationController
  before_action :require_login
  before_action :require_admin, only: [:index]
  before_action :find_ir_issue, only: [:quick_action]

  def index
    open_status_ids = IssueStatus.where(is_closed: false).select(:id)

    @active_incidents = Issue.visible
                             .joins(:tracker, :status)
                             .where(trackers: { name: 'Incident' })
                             .where(status_id: open_status_ids)
                             .preload(:status, :priority, :assigned_to, :project)
                             .order(updated_on: :desc)
                             .limit(50)

    @open_ioc_count = Issue.visible
                           .joins(:tracker, :status)
                           .where(trackers: { name: 'IOC' })
                           .where(status_id: open_status_ids)
                           .count

    @recent_command_updates = Issue.visible
                                   .joins(:tracker)
                                   .where(trackers: { name: 'Command Update' })
                                   .preload(:status, :project)
                                   .order(updated_on: :desc)
                                   .limit(10)
  end

  def quick_action
    unless User.current.allowed_to?(:edit_issues, @issue.project)
      deny_access
      return
    end

    result = RedmineIncidentResponse::QuickActionService.perform(
      @issue, params[:action_key].to_s, User.current
    )

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:error] = result[:message]
    end

    redirect_to issue_path(@issue)
  end

  private

  def find_ir_issue
    @issue = Issue.find(params[:issue_id])
    deny_access unless @issue.visible?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
