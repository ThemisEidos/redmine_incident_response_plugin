module RedmineIncidentResponse
  module Ontology
    module Classifier
      DETECTION_TYPE_MAP = {
        'NAR' => RedmineIncidentResponse::Vernacular::NAR,
        'IOC' => RedmineIncidentResponse::Vernacular::IOC,
        'VALIDATED IOC' => RedmineIncidentResponse::Vernacular::VALIDATED_IOC,
        'OBSERVABLE' => RedmineIncidentResponse::Vernacular::OBSERVABLE,
        'RFI' => RedmineIncidentResponse::Vernacular::RFI,
        'LOE' => RedmineIncidentResponse::Vernacular::LOE,
        'ME' => RedmineIncidentResponse::Vernacular::ME,
        'OPERATIONAL OBJECTIVE' => 'Operational Objective'
      }.freeze

      module_function

      def classify(issue)
        fields = FieldLookup.custom_field_map(issue)
        incident_context = Context.build(issue, fields: fields)

        detection_type = detection_type_for(issue, fields)
        lifecycle_state = lifecycle_state_for(issue, fields, detection_type)

        validation_disposition = fields['Validation Disposition']
        validation_rationale = fields['Validation Rationale']
        validator_identity = fields['Reviewer / Validator']

        escalation_eligibility = escalation_eligibility_for(
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          validation_disposition: validation_disposition,
          validation_rationale: validation_rationale,
          validator_identity: validator_identity
        )

        PanelContext.new(
          incident_id: incident_context.incident_id,
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          analyst_lane: fields['Analyst Lane'].presence || incident_context.analyst_lane,
          escalation_eligibility: escalation_eligibility,
          validation_disposition: validation_disposition,
          operational_impact: fields['Operational Impact'],
          blast_radius: fields['Blast Radius'],
          evidence_reference: fields[RedmineIncidentResponse::Vernacular::EVIDENCE_REFERENCE],
          mitre_tactic: fields['MITRE ATT&CK Tactic'],
          mitre_technique: fields['MITRE ATT&CK Technique'],
          ttp_tags: fields['TTP Tags'],
          cross_incident_correlation_id: fields['Cross-Incident Correlation ID'],
          threat_actor_tags: fields['Threat Actor Tags'],
          validation_rationale: validation_rationale,
          directed_actions: fields['Directed Actions'],
          validator_identity: validator_identity,
          target_assets: fields['Target Assets'],
          quick_actions: quick_actions_for(
            detection_type: detection_type,
            lifecycle_state: lifecycle_state,
            escalation_eligibility: escalation_eligibility
          ),
          messages: []
        )
      end

      def display_text(value)
        value.present? ? value : 'Not set'
      end

      def detection_type_for(issue, fields = nil)
        fields ||= FieldLookup.custom_field_map(issue)
        raw = fields['Detection Type'].presence || issue&.tracker&.name.to_s.strip
        normalized = FieldLookup.normalize(raw)
        return nil if normalized.blank?

        DETECTION_TYPE_MAP[normalized] || normalized
      end

      def lifecycle_state_for(issue, fields = nil, detection_type = nil)
        fields ||= FieldLookup.custom_field_map(issue)
        detection_type ||= detection_type_for(issue, fields)

        fields['Lifecycle State'].presence ||
          default_lifecycle_state_for(detection_type, issue) ||
          'Not set'
      end

      def escalation_eligibility_for(detection_type:, lifecycle_state:, validation_disposition:, validation_rationale:, validator_identity:)
        return 'Not Eligible' if FieldLookup.match?(validation_disposition, 'FALSE POSITIVE')
        return 'Requires Validation' if FieldLookup.match?(validation_disposition, 'UNDER INVESTIGATION')
        return 'Blocked' if invalid_direct_validation?(detection_type, lifecycle_state)

        if FieldLookup.match?(validation_disposition, 'VERIFIED') &&
           validation_rationale.present? &&
           validator_identity.present?
          'Eligible'
        elsif requires_validation_type?(detection_type)
          'Requires Validation'
        else
          'Not Set'
        end
      end

      def quick_actions_for(detection_type:, lifecycle_state:, escalation_eligibility:)
        actions = []

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::NAR)
          actions << { label: 'Promote NAR → IOC', key: 'promote_nar_to_ioc' }
          actions << { label: 'Convert NAR → RFI', key: 'convert_to_rfi' }
        end

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)
          actions << { label: 'Convert OBSERVABLE → IOC', key: 'convert_observable_to_ioc' }
          actions << { label: 'Convert OBSERVABLE → RFI', key: 'convert_to_rfi' }
        end

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::IOC) &&
           !FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
          actions << { label: 'Submit IOC for Validation', key: 'submit_for_validation' }
        end

        if FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::IOC) ||
           FieldLookup.match?(lifecycle_state, 'Pending Validation')
          actions << { label: 'Validate IOC', key: nil }
        end

        if FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC) &&
           escalation_eligibility == 'Eligible'
          actions << { label: 'Escalate to Crew Lead', key: nil }
        end

        actions
      end

      def requires_validation_type?(detection_type)
        [
          RedmineIncidentResponse::Vernacular::NAR,
          RedmineIncidentResponse::Vernacular::OBSERVABLE,
          RedmineIncidentResponse::Vernacular::IOC
        ].any? { |type| FieldLookup.match?(detection_type, type) }
      end
      private_class_method :requires_validation_type?

      def default_lifecycle_state_for(detection_type, issue)
        case FieldLookup.normalize(detection_type)
        when 'NAR'                   then RedmineIncidentResponse::Vernacular::NAR
        when 'IOC'                   then RedmineIncidentResponse::Vernacular::IOC
        when 'VALIDATED IOC'         then RedmineIncidentResponse::Vernacular::VALIDATED_IOC
        when 'OBSERVABLE'            then 'Under Investigation'
        when 'RFI'                   then 'RFI Open'
        when 'LOE'                   then 'LOE Active'
        when 'ME'                    then 'ME Active'
        when 'OPERATIONAL OBJECTIVE' then 'Operational Objective Active'
        else
          Models::IrStatusMap.lifecycle_for(issue&.status&.name) || 'Not set'
        end
      end
      private_class_method :default_lifecycle_state_for

      def invalid_direct_validation?(detection_type, lifecycle_state)
        (FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::NAR) ||
         FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :invalid_direct_validation?
    end
  end
end
