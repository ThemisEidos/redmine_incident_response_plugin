module RedmineIncidentResponse
  module Ontology
    module IssuePresenter
      module_function

      def panel_context(issue, classification: nil, guard: nil)
        classification ||= Classifier.classify(issue)
        guard ||= TransitionGuard.evaluate(issue, classification: classification)

        context = classification.dup
        context.messages = guard.messages
        context
      end

      def panel_locals(issue)
        classification = Classifier.classify(issue)
        guard = TransitionGuard.evaluate(issue, classification: classification)

        {
          issue: issue,
          ir_context: Context.build(issue),
          ontology: panel_context(issue, classification: classification, guard: guard),
          guard: guard,
          loe_context: Models::LoeContext.build(issue)
        }
      end

      def panel_partial
        'hooks/redmine_incident_response/issue_ontology_panel'
      end

      def display_text(value)
        return 'Not set' if value.nil?

        if value.respond_to?(:empty?) && value.empty?
          'Not set'
        elsif value.is_a?(Array)
          value.compact.map(&:to_s).reject(&:empty?).join(', ').presence || 'Not set'
        else
          value.to_s.presence || 'Not set'
        end
      end
    end
  end
end
