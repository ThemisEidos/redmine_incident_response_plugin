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
      handle_ontology_save_hook(context, :new)
    end

    def controller_issues_edit_after_save(context = {})
      handle_ontology_save_hook(context, :edit)
    end

    private

    def handle_ontology_save_hook(context, action)
      issue = context[:issue]
      return unless issue

      guard = Ontology::TransitionGuard.evaluate(issue)
      return if guard.allowed

      Redmine.logger.debug("Ontology guard triggered on #{action} save for Issue ID: #{issue.id}") if defined?(Redmine) && Redmine.respond_to?(:logger)

      if context[:controller]&.respond_to?(:flash) && guard.messages.any?
        context[:controller].flash[:warning] = guard.messages.join(' ')
      end
    end
  end
end
