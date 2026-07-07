require_relative 'test_helper'

class FieldLookupTest < Minitest::Test
  FL = RedmineIncidentResponse::FieldLookup

  def test_custom_field_map_builds_name_keyed_hash
    issue = StubIssue.new(fields: { 'Detection Type' => 'IOC', 'Lifecycle State' => 'Pending Validation' })
    map = FL.custom_field_map(issue)
    assert_equal 'IOC', map['Detection Type']
    assert_equal 'Pending Validation', map['Lifecycle State']
  end

  def test_custom_field_map_handles_nil_issue
    assert_equal({}, FL.custom_field_map(nil))
  end

  def test_custom_field_value_reads_single_field
    issue = StubIssue.new(fields: { 'LOE' => 'LOE-ALPHA' })
    assert_equal 'LOE-ALPHA', FL.custom_field_value(issue, 'LOE')
    assert_nil FL.custom_field_value(issue, 'Missing Field')
  end

  def test_normalize_collapses_case_separators_whitespace
    assert_equal 'VALIDATED IOC', FL.normalize('  validated_ioc ')
    assert_equal 'VALIDATED IOC', FL.normalize("Validated-IOC")
    assert_equal '', FL.normalize(nil)
  end

  def test_match_ignores_case_whitespace_and_separators
    assert FL.match?('validated_ioc', 'VALIDATED IOC')
    assert FL.match?('  Validated-IOC ', 'VALIDATED IOC')
    refute FL.match?('IOC', 'VALIDATED IOC')
  end
end
