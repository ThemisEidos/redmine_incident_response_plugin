module RedmineIncidentResponse
  module IssuePatch
    def self.included(base)
      base.validate :validate_ir_ontology_transition
    end

    def validate_ir_ontology_transition
      guard = Ontology::TransitionGuard.evaluate(self)
      return if guard.allowed

      guard.messages.each { |msg| errors.add(:base, msg) }
    end
  end
end
