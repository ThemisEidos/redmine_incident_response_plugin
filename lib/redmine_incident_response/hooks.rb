module RedmineIncidentResponse
  class Hooks < Redmine::Hook::ViewListener
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      controller = context[:controller]
      return '' unless issue.present? && controller

      ir_panel = controller.send(
        :render_to_string,
        partial: 'hooks/redmine_incident_response/issue_ir_panel',
        locals: { issue: issue }
      )

      ontology_panel =
        begin
          controller.send(
            :render_to_string,
            partial: RedmineIncidentResponse::IssueHelper.panel_partial,
            locals: RedmineIncidentResponse::IssueHelper.panel_locals(issue)
          )
        rescue StandardError => e
          log_ontology_render_error(issue, e)
          ''
        end

      ir_panel + ontology_panel
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

    def log_ontology_render_error(issue, error)
      return unless defined?(Redmine) && Redmine.respond_to?(:logger)

      Redmine.logger.error("IR Hook: ontology panel render failed for issue #{issue&.id}: #{error.class}: #{error.message}")
    end
  end
end
