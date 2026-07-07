module RedmineIncidentResponse
  module Ontology
    module IssuePresenter
      module_function

      def panel_context(issue)
        classification = Classifier.classify(issue)
        guard = TransitionGuard.evaluate(issue)

        PanelContext.new(
          incident_id: classification.incident_id,
          detection_type: classification.detection_type,
          lifecycle_state: classification.lifecycle_state,
          analyst_lane: classification.analyst_lane,
          escalation_eligibility: classification.escalation_eligibility,
          validation_disposition: classification.validation_disposition,
          operational_impact: classification.operational_impact,
          blast_radius: classification.blast_radius,
          evidence_reference: classification.evidence_reference,
          mitre_tactic: classification.mitre_tactic,
          mitre_technique: classification.mitre_technique,
          ttp_tags: classification.ttp_tags,
          cross_incident_correlation_id: classification.cross_incident_correlation_id,
          threat_actor_tags: classification.threat_actor_tags,
          validation_rationale: classification.validation_rationale,
          directed_actions: classification.directed_actions,
          validator_identity: classification.validator_identity,
          target_assets: classification.target_assets,
          quick_actions: classification.quick_actions,
          messages: guard.messages
        )
      end

      def panel_locals(issue)
        {
          issue: issue,
          ir_context: Context.build(issue),
          ontology: panel_context(issue),
          guard: TransitionGuard.evaluate(issue),
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
