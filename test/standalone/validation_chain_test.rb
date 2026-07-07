require_relative 'test_helper'

class ValidationChainTest < Minitest::Test
  VC = RedmineIncidentResponse::Models::ValidationChain

  def test_roles_match_ir_setup_rake_roles
    assert_equal ['Operator', 'Crew Lead', 'Team Lead', 'Commander'], VC::ROLES
  end

  def test_chain_order
    assert_equal 'Crew Lead', VC.next_step('Operator')
    assert_equal 'Team Lead', VC.next_step('Crew Lead')
    assert_equal 'Commander', VC.next_step('Team Lead')
    assert_nil VC.next_step('Commander')
  end

  def test_unknown_role_returns_nil
    assert_nil VC.next_step('Random Role')
  end

  def test_escalate_payload
    payload = VC.escalate(StubIssue.new(id: 5), 'Operator')
    assert_equal 5, payload[:issue_id]
    assert_equal 'Crew Lead', payload[:next_role]
    assert payload[:escalatable]
  end
end
