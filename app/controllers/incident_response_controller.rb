class IncidentResponseController < ApplicationController
  before_action :require_login
  before_action :require_admin, only: [:index]
  before_action :find_ir_issue, only: [:quick_action]

  def index
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
