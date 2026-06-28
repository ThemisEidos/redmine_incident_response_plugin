module RedmineIncidentResponse
  class Hooks < Redmine::Hook::ViewListener
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      Redmine.logger.debug(IssueHelper.panel_debug_message(issue)) if defined?(Redmine) && Redmine.respond_to?(:logger)

      return '' unless IssueHelper.panel_visible?(issue)

      controller = context[:controller]
      return '' unless controller

      controller.send(
        :render_to_string,
        partial: IssueHelper.panel_partial,
        locals: IssueHelper.panel_locals(issue)
      )
    end

    def controller_issues_new_after_save(context = {})
      log_ontology_save(context[:issue], :new)
    end

    def controller_issues_edit_after_save(context = {})
      log_ontology_save(context[:issue], :edit)
    end

    private

    def log_ontology_save(issue, action)
      return unless issue && defined?(Redmine) && Redmine.respond_to?(:logger)

      Redmine.logger.debug("IR Hook: issue #{issue.id} #{action} save completed (ontology: #{issue.tracker&.name})")
    end
  end
end
