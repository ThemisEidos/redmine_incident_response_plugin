module RedmineIncidentResponse
  module IssuePatch
    IR_TRACKER_NAMES = [
      'Incident',
      Vernacular::NAR,
      Vernacular::IOC,
      Vernacular::VALIDATED_IOC,
      Vernacular::OBSERVABLE,
      Vernacular::RFI,
      Vernacular::SITREP,
      Vernacular::AAR,
      Vernacular::LOE,
      Vernacular::ME
    ].freeze

    def self.included(base)
      base.validate :validate_ir_ontology_transition
    end

    def self.ir_issue?(issue)
      tracker_name = issue&.tracker&.name
      return false if tracker_name.blank?

      IR_TRACKER_NAMES.any? { |name| FieldLookup.match?(tracker_name, name) }
    end

    def validate_ir_ontology_transition
      return unless RedmineIncidentResponse::IssuePatch.ir_issue?(self)

      guard = Ontology::TransitionGuard.evaluate(self)
      return if guard.allowed

      guard.messages.each { |msg| errors.add(:base, msg) }
    end
  end
end
