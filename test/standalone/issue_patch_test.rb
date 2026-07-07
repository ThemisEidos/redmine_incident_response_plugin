require_relative 'test_helper'

class IssuePatchTest < Minitest::Test
  IP = RedmineIncidentResponse::IssuePatch

  def test_ir_issue_true_for_vernacular_trackers
    ['Incident', 'IOC', 'NAR', 'OBSERVABLE', 'RFI', 'SITREP', 'AAR', 'LOE', 'ME', 'Validated IOC'].each do |name|
      assert IP.ir_issue?(StubIssue.new(tracker: StubTracker.new(name))), "expected #{name} to be an IR tracker"
    end
  end

  def test_ir_issue_false_for_other_trackers
    ['Bug', 'Feature', 'Support', 'Analysis Task', 'Command Update', 'Evidence Item'].each do |name|
      refute IP.ir_issue?(StubIssue.new(tracker: StubTracker.new(name))), "expected #{name} not to be an IR tracker"
    end
  end

  def test_ir_issue_false_without_tracker
    refute IP.ir_issue?(StubIssue.new)
    refute IP.ir_issue?(nil)
  end
end
