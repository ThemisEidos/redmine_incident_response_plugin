module RedmineIncidentResponse
  module Context
    ANALYST_LANES = ['CTI', 'Host', 'Network', 'Forensics'].freeze
    DEFAULT_SEVERITY = 'MEDIUM'
    DEFAULT_STATUS = 'New'

    def self.build(issue, fields: nil)
      fields ||= FieldLookup.custom_field_map(issue)
      issue_id = issue&.id

      Models::IrContext.new(
        incident_id: issue_id ? "ISSUE-#{issue_id}" : nil,
        severity: severity_for(issue, fields),
        analyst_lane: fields['Analyst Lane'].presence&.to_s,
        ir_status: fields['IR Status'].presence&.to_s || DEFAULT_STATUS
      )
    end

    def self.severity_for(issue, fields)
      value = fields['IR Severity']
      return normalize_severity(value) if value.present?

      priority_name = issue&.priority&.name
      return normalize_severity(priority_name) if priority_name.present?

      DEFAULT_SEVERITY
    end

    def self.normalize_severity(value)
      case value.to_s.strip.upcase
      when 'LOW', 'L'                              then 'LOW'
      when 'MEDIUM', 'MED', 'M', 'NORMAL'          then 'MEDIUM'
      when 'HIGH', 'H'                             then 'HIGH'
      when 'CRITICAL', 'CRIT', 'URGENT', 'IMMEDIATE' then 'CRITICAL'
      else DEFAULT_SEVERITY
      end
    end
    private_class_method :normalize_severity
  end
end
