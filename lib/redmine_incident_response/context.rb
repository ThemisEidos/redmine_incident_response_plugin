module RedmineIncidentResponse
  module Context
    ANALYST_LANES = ['CTI', 'Host', 'Network', 'Forensics'].freeze
    DEFAULT_SEVERITY = 'MEDIUM'
    DEFAULT_STATUS = 'New'

    def self.build(issue)
      issue_id = issue&.id
      incident_id = issue_id ? "ISSUE-#{issue_id}" : nil

      Models::IrContext.new(
        incident_id: incident_id,
        severity: severity_for(issue),
        analyst_lane: analyst_lane_for(issue),
        ir_status: ir_status_for(issue)
      )
    end

    def self.severity_for(issue)
      value = custom_field_value(issue, 'IR Severity')
      return normalize_severity(value) if value.present?

      priority_name = issue&.priority&.name
      return normalize_severity(priority_name) if priority_name.present?

      DEFAULT_SEVERITY
    end

    def self.analyst_lane_for(issue)
      value = custom_field_value(issue, 'Analyst Lane')
      return value.to_s if value.present?

      return ANALYST_LANES[(issue.id.to_i - 1) % ANALYST_LANES.length] if issue&.id.present?

      ANALYST_LANES.first
    end

    def self.ir_status_for(issue)
      value = custom_field_value(issue, 'IR Status')
      return value.to_s if value.present?

      DEFAULT_STATUS
    end

    def self.custom_field_value(issue, field_name)
      return nil unless issue&.respond_to?(:custom_field_values)

      custom_field = issue.custom_field_values.find do |field_value|
        field_value.custom_field&.name == field_name
      end

      custom_field&.value
    end
    private_class_method :custom_field_value

    def self.normalize_severity(value)
      normalized = value.to_s.strip.upcase
      return DEFAULT_SEVERITY if normalized.blank?

      case normalized
      when 'LOW', 'L'
        'LOW'
      when 'MEDIUM', 'MED', 'M'
        'MEDIUM'
      when 'HIGH', 'H'
        'HIGH'
      when 'CRITICAL', 'CRIT'
        'CRITICAL'
      else
        DEFAULT_SEVERITY
      end
    end
    private_class_method :normalize_severity
  end
end
