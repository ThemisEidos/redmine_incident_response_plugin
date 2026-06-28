module RedmineIncidentResponse
  module Ontology
    module Classifier
      DETECTION_TYPE_MAP = {
        RedmineIncidentResponse::Vernacular::NAR => RedmineIncidentResponse::Vernacular::NAR,
        RedmineIncidentResponse::Vernacular::IOC => RedmineIncidentResponse::Vernacular::IOC,
        RedmineIncidentResponse::Vernacular::VALIDATED_IOC => RedmineIncidentResponse::Vernacular::VALIDATED_IOC,
        RedmineIncidentResponse::Vernacular::OBSERVABLE => RedmineIncidentResponse::Vernacular::OBSERVABLE,
        RedmineIncidentResponse::Vernacular::RFI => RedmineIncidentResponse::Vernacular::RFI,
        RedmineIncidentResponse::Vernacular::LOE => RedmineIncidentResponse::Vernacular::LOE,
        RedmineIncidentResponse::Vernacular::ME => RedmineIncidentResponse::Vernacular::ME,
        'OPERATIONAL OBJECTIVE' => 'Operational Objective'
      }.freeze

      module_function

      def classify(issue)
        incident_context = IncidentResponseContext.build(issue)
        detection_type = detection_type_for(issue)
        lifecycle_state = lifecycle_state_for(issue)
        analyst_lane = analyst_lane_for(issue)
        validation_disposition = custom_field_value(issue, 'Validation Disposition')
        operational_impact = custom_field_value(issue, 'Operational Impact')
        blast_radius = custom_field_value(issue, 'Blast Radius')
        evidence_reference = custom_field_value(issue, RedmineIncidentResponse::Vernacular::EVIDENCE_REFERENCE)
        mitre_tactic = custom_field_value(issue, 'MITRE ATT&CK Tactic')
        mitre_technique = custom_field_value(issue, 'MITRE ATT&CK Technique')
        ttp_tags = custom_field_value(issue, 'TTP Tags')
        correlation_id = custom_field_value(issue, 'Cross-Incident Correlation ID')
        threat_actor_tags = custom_field_value(issue, 'Threat Actor Tags')
        validation_rationale = custom_field_value(issue, 'Validation Rationale')
        directed_actions = custom_field_value(issue, 'Directed Actions')
        validator_identity = custom_field_value(issue, 'Reviewer / Validator')
        target_assets = custom_field_value(issue, 'Target Assets')

        escalation_eligibility = escalation_eligibility_for(
          issue,
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          validation_disposition: validation_disposition,
          validation_rationale: validation_rationale,
          validator_identity: validator_identity
        )

        quick_actions = quick_actions_for(
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          escalation_eligibility: escalation_eligibility
        )

        PanelContext.new(
          incident_id: incident_context.incident_id,
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          analyst_lane: analyst_lane,
          escalation_eligibility: escalation_eligibility,
          validation_disposition: validation_disposition,
          operational_impact: operational_impact,
          blast_radius: blast_radius,
          evidence_reference: evidence_reference,
          mitre_tactic: mitre_tactic,
          mitre_technique: mitre_technique,
          ttp_tags: ttp_tags,
          cross_incident_correlation_id: correlation_id,
          threat_actor_tags: threat_actor_tags,
          validation_rationale: validation_rationale,
          directed_actions: directed_actions,
          validator_identity: validator_identity,
          target_assets: target_assets,
          quick_actions: quick_actions,
          messages: []
        )
      end

      def display_text(value)
        value.present? ? value : 'Not set'
      end

      def detection_type_for(issue)
        normalize_detection_type(
          custom_field_value(issue, 'Detection Type') ||
          tracker_name_candidate(issue)
        )
      end

      def lifecycle_state_for(issue)
        custom_field_value(issue, 'Lifecycle State').presence ||
          default_lifecycle_state_for(detection_type_for(issue), issue) ||
          'Not set'
      end

      def analyst_lane_for(issue)
        custom_field_value(issue, 'Analyst Lane').presence ||
          IncidentResponseContext.build(issue).analyst_lane
      end

      def escalation_eligibility_for(issue, detection_type:, lifecycle_state:, validation_disposition:, validation_rationale:, validator_identity:)
        return 'Not Eligible' if normalization_match?(validation_disposition, 'FALSE POSITIVE')
        return 'Requires Validation' if normalization_match?(validation_disposition, 'UNDER INVESTIGATION')
        return 'Blocked' if invalid_direct_validation?(detection_type, lifecycle_state)

        if normalization_match?(validation_disposition, 'VERIFIED') &&
           validation_rationale.present? &&
           validator_identity.present?
          'Eligible'
        elsif normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::NAR) || normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)
          'Requires Validation'
        elsif normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::IOC)
          'Requires Validation'
        else
          'Not Set'
        end
      end

      def quick_actions_for(detection_type:, lifecycle_state:, escalation_eligibility:)
        actions = []
        if normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::NAR)
          actions << { label: 'Promote NAR → IOC', key: 'promote_nar_to_ioc' }
        end
        if normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::IOC) && lifecycle_state != RedmineIncidentResponse::Vernacular::VALIDATED_IOC
          actions << { label: 'Submit IOC for Validation', key: 'submit_for_validation' }
        end
        if normalization_match?(lifecycle_state, RedmineIncidentResponse::Vernacular::IOC) || lifecycle_state == 'Pending Validation'
          actions << { label: 'Validate IOC', key: nil }
        end
        if lifecycle_state == RedmineIncidentResponse::Vernacular::VALIDATED_IOC && escalation_eligibility == 'Eligible'
          actions << { label: 'Escalate to Crew Lead', key: nil }
        end
        if normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)
          actions << { label: 'Convert OBSERVABLE → IOC', key: 'convert_observable_to_ioc' }
        end
        if normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::RFI)
          actions << { label: 'Convert to RFI', key: 'convert_to_rfi' }
        end
        actions
      end

      def custom_field_value(issue, field_name)
        return nil unless issue&.respond_to?(:custom_field_values)

        value = issue.custom_field_values.find do |field_value|
          field_value.custom_field&.name == field_name
        end

        value&.value
      end
      private_class_method :custom_field_value

      def status_name(issue)
        issue&.status&.name
      end
      private_class_method :status_name

      def tracker_name_candidate(issue)
        issue&.tracker&.name.to_s.strip
      end
      private_class_method :tracker_name_candidate

      def normalize_detection_type(value)
        normalized = value.to_s.strip.upcase.tr('_-', ' ').gsub(/\s+/, ' ')
        return nil if normalized.blank?

        DETECTION_TYPE_MAP[normalized] || normalized
      end
      private_class_method :normalize_detection_type

      def default_lifecycle_state_for(detection_type, issue)
        case detection_type.to_s.strip.upcase
        when RedmineIncidentResponse::Vernacular::NAR
          RedmineIncidentResponse::Vernacular::NAR
        when RedmineIncidentResponse::Vernacular::IOC
          RedmineIncidentResponse::Vernacular::IOC
        when RedmineIncidentResponse::Vernacular::VALIDATED_IOC
          RedmineIncidentResponse::Vernacular::VALIDATED_IOC
        when RedmineIncidentResponse::Vernacular::OBSERVABLE
          'Under Investigation'
        when RedmineIncidentResponse::Vernacular::RFI
          'RFI Open'
        when RedmineIncidentResponse::Vernacular::LOE
          'LOE Active'
        when RedmineIncidentResponse::Vernacular::ME
          'ME Active'
        when 'OPERATIONAL OBJECTIVE'
          'Operational Objective Active'
        else
          IRStatusMap.lifecycle_for(status_name(issue), IRStatusMap::DEFAULT_MAP) || 'Not set'
        end
      end
      private_class_method :default_lifecycle_state_for

      def normalization_match?(value, expected)
        normalize_compare_value(value) == normalize_compare_value(expected)
      end
      private_class_method :normalization_match?

      def normalize_compare_value(value)
        value.to_s.strip.upcase.tr('_-', ' ').gsub(/\s+/, ' ')
      end
      private_class_method :normalize_compare_value

      def invalid_direct_validation?(detection_type, lifecycle_state)
        (normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::NAR) || normalization_match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          normalization_match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :invalid_direct_validation?
    end
  end
end
