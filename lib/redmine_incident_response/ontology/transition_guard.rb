module RedmineIncidentResponse
  module Ontology
    module TransitionGuard
      Result = Struct.new(
        :allowed,
        :suggested_lifecycle_state,
        :messages,
        :notices,
        :normalized_detection_type,
        :normalized_lifecycle_state,
        keyword_init: true
      )

      module_function

      def evaluate(issue, classification: nil)
        classification ||= Classifier.classify(issue)
        messages = []
        notices = []
        suggested_lifecycle_state = classification.lifecycle_state

        if direct_validation_blocked?(classification)
          messages << 'NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC.'
          suggested_lifecycle_state = RedmineIncidentResponse::Vernacular::IOC
        end

        if FieldLookup.match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
          if classification.validation_disposition.to_s.strip.empty?
            messages << 'VALIDATED IOC requires a Validation Disposition.'
          end

          if classification.validation_rationale.to_s.strip.empty? &&
             !FieldLookup.match?(classification.validation_disposition, 'UNDER INVESTIGATION')
            messages << 'VALIDATED IOC requires a Validation Rationale unless disposition is UNDER INVESTIGATION.'
          end

          if classification.validator_identity.to_s.strip.empty?
            messages << 'VALIDATED IOC requires a Reviewer / Validator.'
          end
        end

        if FieldLookup.match?(classification.validation_disposition, 'FALSE POSITIVE')
          notices << 'FALSE POSITIVE: this issue is not eligible for escalation.'
        end

        Result.new(
          allowed: messages.empty?,
          suggested_lifecycle_state: suggested_lifecycle_state,
          messages: messages,
          notices: notices,
          normalized_detection_type: classification.detection_type,
          normalized_lifecycle_state: classification.lifecycle_state
        )
      end

      def direct_validation_blocked?(classification)
        (FieldLookup.match?(classification.detection_type, RedmineIncidentResponse::Vernacular::NAR) ||
         FieldLookup.match?(classification.detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          FieldLookup.match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :direct_validation_blocked?
    end
  end
end
