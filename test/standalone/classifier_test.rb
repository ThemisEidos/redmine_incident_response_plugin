require_relative 'test_helper'

class ClassifierTest < Minitest::Test
  C = RedmineIncidentResponse::Ontology::Classifier

  def keys_for(issue)
    C.classify(issue).quick_actions.map { |a| a[:key] }
  end

  def test_detection_type_falls_back_to_tracker_name
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    assert_equal 'IOC', C.classify(issue).detection_type
  end

  def test_detection_type_prefers_custom_field_and_normalizes
    issue = StubIssue.new(tracker: StubTracker.new('Bug'), fields: { 'Detection Type' => 'nar' })
    assert_equal 'NAR', C.classify(issue).detection_type
  end

  def test_nar_offers_promote_and_rfi_conversion
    issue = StubIssue.new(tracker: StubTracker.new('NAR'))
    assert_includes keys_for(issue), 'promote_nar_to_ioc'
    assert_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_observable_offers_ioc_and_rfi_conversion
    issue = StubIssue.new(tracker: StubTracker.new('OBSERVABLE'))
    assert_includes keys_for(issue), 'convert_observable_to_ioc'
    assert_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_rfi_issue_gets_no_rfi_conversion
    # F3: the old code offered "Convert to RFI" only when the issue already WAS an RFI.
    issue = StubIssue.new(tracker: StubTracker.new('RFI'))
    refute_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_submit_for_validation_hidden_when_already_validated_regardless_of_case
    # F5: the old code used a raw != compare here.
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Lifecycle State' => 'validated ioc' })
    refute_includes keys_for(issue), 'submit_for_validation'
  end

  def test_ioc_offers_submit_for_validation
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    assert_includes keys_for(issue), 'submit_for_validation'
  end

  def test_verified_ioc_with_rationale_and_validator_is_eligible
    issue = StubIssue.new(
      tracker: StubTracker.new('IOC'),
      fields: {
        'Validation Disposition' => 'VERIFIED',
        'Validation Rationale'   => 'Confirmed via EDR telemetry',
        'Reviewer / Validator'   => 'crew.lead'
      }
    )
    assert_equal 'Eligible', C.classify(issue).escalation_eligibility
  end

  def test_false_positive_is_not_eligible
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Validation Disposition' => 'False Positive' })
    assert_equal 'Not Eligible', C.classify(issue).escalation_eligibility
  end

  def test_unset_analyst_lane_is_nil_not_fabricated
    # F6: the old code assigned a lane from issue.id % 4.
    issue = StubIssue.new(id: 7, tracker: StubTracker.new('IOC'))
    assert_nil C.classify(issue).analyst_lane
  end
end
