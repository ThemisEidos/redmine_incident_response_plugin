module RedmineIncidentResponse
  module IssueHelper
    module_function

    def panel_visible?(issue)
      issue.present?
    end

    def panel_locals(issue)
      Ontology::IssuePresenter.panel_locals(issue)
    end

    def panel_partial
      Ontology::IssuePresenter.panel_partial
    end

    def panel_debug_message(issue)
      "IR Hook triggered for Issue ID: #{issue&.id || 'nil'}"
    end
  end
end
