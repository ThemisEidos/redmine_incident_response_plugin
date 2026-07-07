require_relative 'test_helper'

class ContextTest < Minitest::Test
  CTX = RedmineIncidentResponse::Context

  def test_incident_id_format
    assert_equal 'ISSUE-42', CTX.build(StubIssue.new(id: 42)).incident_id
  end

  def test_analyst_lane_nil_when_unset
    assert_nil CTX.build(StubIssue.new(id: 7)).analyst_lane
  end

  def test_analyst_lane_from_custom_field
    assert_equal 'Host', CTX.build(StubIssue.new(fields: { 'Analyst Lane' => 'Host' })).analyst_lane
  end

  def test_severity_from_custom_field_wins
    issue = StubIssue.new(priority: StubPriority.new('Low'), fields: { 'IR Severity' => 'crit' })
    assert_equal 'CRITICAL', CTX.build(issue).severity
  end

  def test_priority_urgent_maps_to_critical
    assert_equal 'CRITICAL', CTX.build(StubIssue.new(priority: StubPriority.new('Urgent'))).severity
  end

  def test_priority_immediate_maps_to_critical
    assert_equal 'CRITICAL', CTX.build(StubIssue.new(priority: StubPriority.new('Immediate'))).severity
  end

  def test_priority_normal_maps_to_medium
    assert_equal 'MEDIUM', CTX.build(StubIssue.new(priority: StubPriority.new('Normal'))).severity
  end

  def test_ir_status_defaults_to_new
    assert_equal 'New', CTX.build(StubIssue.new).ir_status
  end
end
