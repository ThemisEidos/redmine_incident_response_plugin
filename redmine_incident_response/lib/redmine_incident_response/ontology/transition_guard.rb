module RedmineIncidentResponse
  module Ontology
    module TransitionGuard
      Result = Struct.new(
        :allowed,
        :suggested_lifecycle_state,
        :messages,
        :normalized_detection_type,
        :normalized_lifecycle_state,
        keyword_init: true
      )

      module_function

      def evaluate(issue)
        classification = Classifier.classify(issue)
        messages = []
        suggested_lifecycle_state = classification.lifecycle_state

        if direct_validation_blocked?(classification)
          messages << 'Ontology guard: NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC.'
          suggested_lifecycle_state = RedmineIncidentResponse::Vernacular::IOC
        end

        if classification.lifecycle_state == RedmineIncidentResponse::Vernacular::VALIDATED_IOC
          if classification.validation_disposition.nil? || classification.validation_disposition.to_s.strip.empty?
            messages << 'Ontology guard: VALIDATED IOC requires a Validation Disposition.'
          end

          if classification.validation_rationale.nil? || classification.validation_rationale.to_s.strip.empty?
            unless normalization_match?(classification.validation_disposition, 'UNDER INVESTIGATION')
              messages << 'Ontology guard: VALIDATED IOC requires a Validation Rationale unless disposition is UNDER INVESTIGATION.'
            end
          end

          if classifier_requires_validation_identity?(classification)
            messages << 'Ontology guard: VALIDATED IOC requires a Reviewer / Validator.'
          end
        end

        if normalization_match?(classification.validation_disposition, 'FALSE POSITIVE')
          messages << 'Ontology guard: FALSE POSITIVE marks the issue as not eligible for escalation.'
        end

        Result.new(
          allowed: messages.empty?,
          suggested_lifecycle_state: suggested_lifecycle_state,
          messages: messages,
          normalized_detection_type: classification.detection_type,
          normalized_lifecycle_state: classification.lifecycle_state
        )
      end

      def direct_validation_blocked?(classification)
        (normalization_match?(classification.detection_type, RedmineIncidentResponse::Vernacular::NAR) ||
         normalization_match?(classification.detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          normalization_match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :direct_validation_blocked?

      def classifier_requires_validation_identity?(classification)
        normalization_match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC) &&
          (classification.validator_identity.nil? || classification.validator_identity.to_s.strip.empty?)
      end
      private_class_method :classifier_requires_validation_identity?

      def normalization_match?(value, expected)
        normalize_compare_value(value) == normalize_compare_value(expected)
      end
      private_class_method :normalization_match?

      def normalize_compare_value(value)
        value.to_s.strip.upcase.tr('_-', ' ').gsub(/\s+/, ' ')
      end
      private_class_method :normalize_compare_value
    end
  end
end
