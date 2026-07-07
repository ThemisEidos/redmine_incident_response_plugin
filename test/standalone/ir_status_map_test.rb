require_relative 'test_helper'

class IrStatusMapTest < Minitest::Test
  M = RedmineIncidentResponse::Models::IrStatusMap

  def test_maps_all_ir_setup_statuses
    assert_equal 'Triage', M.lifecycle_for('New')
    assert_equal 'Analysis', M.lifecycle_for('In Progress')
    assert_equal 'Pending Validation', M.lifecycle_for('Pending Validation')
    assert_equal 'Validated IOC', M.lifecycle_for('Validated IOC')
    assert_equal 'Escalated', M.lifecycle_for('Escalated')
    assert_equal 'Closed', M.lifecycle_for('Closed')
  end

  def test_unknown_status_passes_through
    assert_equal 'Feedback', M.lifecycle_for('Feedback')
  end

  def test_nil_returns_nil
    assert_nil M.lifecycle_for(nil)
  end

  def test_default_map_explicitly_contains_identity_mapped_statuses
    # Regression test: verify identity-mapped keys are explicit in DEFAULT_MAP,
    # not just coincidentally returned by the fallback behavior
    ['Pending Validation', 'Validated IOC', 'Escalated'].each do |status|
      assert M::DEFAULT_MAP.key?(status), "expected DEFAULT_MAP to have an explicit entry for #{status.inspect}"
    end
  end

  def test_unmapped_status_falls_through_unchanged
    # Verify the fallback behavior is intentional: unmapped statuses return unchanged
    assert_equal 'Some Unknown Status', M.lifecycle_for('Some Unknown Status')
  end
end
