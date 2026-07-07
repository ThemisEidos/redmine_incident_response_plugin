require_relative 'test_helper'

class TransitionGuardTest < Minitest::Test
  TG = RedmineIncidentResponse::Ontology::TransitionGuard

  def test_nar_cannot_jump_to_validated_ioc
    issue = StubIssue.new(tracker: StubTracker.new('NAR'), fields: { 'Lifecycle State' => 'VALIDATED IOC' })
    result = TG.evaluate(issue)
    refute result.allowed
    assert_includes result.messages, 'NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC.'
    assert_equal RedmineIncidentResponse::Vernacular::IOC, result.suggested_lifecycle_state
  end

  def test_validated_ioc_requires_disposition_rationale_and_validator
    issue = StubIssue.new(tracker: StubTracker.new('VALIDATED IOC'))
    result = TG.evaluate(issue)
    refute result.allowed
    assert_equal 3, result.messages.length
  end

  def test_complete_validated_ioc_is_allowed
    issue = StubIssue.new(
      tracker: StubTracker.new('VALIDATED IOC'),
      fields: {
        'Validation Disposition' => 'VERIFIED',
        'Validation Rationale'   => 'Confirmed',
        'Reviewer / Validator'   => 'crew.lead'
      }
    )
    assert TG.evaluate(issue).allowed
  end

  def test_false_positive_produces_notice
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Validation Disposition' => 'FALSE POSITIVE' })
    result = TG.evaluate(issue)
    assert result.allowed
    assert_includes result.notices, 'FALSE POSITIVE: this issue is not eligible for escalation.'
  end

  def test_evaluate_accepts_precomputed_classification
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    classification = RedmineIncidentResponse::Ontology::Classifier.classify(issue)
    result = TG.evaluate(issue, classification: classification)
    assert result.allowed
  end
end
