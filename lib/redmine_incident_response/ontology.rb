module RedmineIncidentResponse
  module Ontology
    PanelContext = Struct.new(
      :incident_id,
      :detection_type,
      :lifecycle_state,
      :analyst_lane,
      :escalation_eligibility,
      :validation_disposition,
      :operational_impact,
      :blast_radius,
      :evidence_reference,
      :mitre_tactic,
      :mitre_technique,
      :ttp_tags,
      :cross_incident_correlation_id,
      :threat_actor_tags,
      :validation_rationale,
      :directed_actions,
      :validator_identity,
      :target_assets,
      :quick_actions,
      :messages,
      keyword_init: true
    )
  end
end
