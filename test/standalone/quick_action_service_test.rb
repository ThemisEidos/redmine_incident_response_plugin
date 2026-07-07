require_relative 'test_helper'

class QuickActionServiceTest < Minitest::Test
  QAS = RedmineIncidentResponse::QuickActionService
  StubRole = Struct.new(:name)

  class StubUser
    def initialize(role_names)
      @role_names = role_names
    end

    def roles_for_project(_project)
      @role_names.map { |name| StubRole.new(name) }
    end
  end

  def validated_ioc_issue
    StubIssue.new(
      tracker: StubTracker.new('IOC'),
      fields: { 'Lifecycle State' => 'VALIDATED IOC' }
    )
  end

  def test_escalate_sets_lifecycle_and_reports_next_role
    issue = validated_ioc_issue
    result = QAS.perform(issue, 'escalate', StubUser.new(['Operator']))
    assert result[:success], result[:message]
    assert_match(/Crew Lead/, result[:message])
    assert_equal 'Escalated', RedmineIncidentResponse::FieldLookup.custom_field_value(issue, 'Lifecycle State')
  end

  def test_escalate_picks_highest_matching_role
    result = QAS.perform(validated_ioc_issue, 'escalate', StubUser.new(['Operator', 'Team Lead']))
    assert result[:success], result[:message]
    assert_match(/Commander/, result[:message])
  end

  def test_escalate_fails_at_top_of_chain
    result = QAS.perform(validated_ioc_issue, 'escalate', StubUser.new(['Commander']))
    refute result[:success]
  end

  def test_unknown_action_fails
    result = QAS.perform(validated_ioc_issue, 'bogus_action', StubUser.new(['Operator']))
    refute result[:success]
    assert_match(/Unknown quick action/, result[:message])
  end

  def test_submit_for_validation_sets_pending
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Lifecycle State' => 'IOC' })
    result = QAS.perform(issue, 'submit_for_validation', StubUser.new(['Operator']))
    assert result[:success], result[:message]
    assert_equal 'Pending Validation', RedmineIncidentResponse::FieldLookup.custom_field_value(issue, 'Lifecycle State')
  end
end
