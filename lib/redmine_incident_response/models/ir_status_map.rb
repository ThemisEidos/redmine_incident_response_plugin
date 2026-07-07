module RedmineIncidentResponse
  module Models
    module IrStatusMap
      DEFAULT_MAP = {
        'New' => 'Triage',
        'In Progress' => 'Analysis',
        'Pending Validation' => 'Pending Validation',
        'Validated IOC' => 'Validated IOC',
        'Escalated' => 'Escalated',
        'Resolved' => 'Recovery',
        'Closed' => 'Closed'
      }.freeze

      module_function

      def lifecycle_for(status_name, map = DEFAULT_MAP)
        return nil if status_name.nil?

        map[status_name.to_s] || map[status_name.to_s.strip] || status_name.to_s
      end
    end
  end
end
