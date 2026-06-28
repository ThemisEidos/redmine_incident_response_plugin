module RedmineIncidentResponse
  module Models
    IncidentContext = Struct.new(:incident_id, :severity, :analyst_lane, :ir_status, keyword_init: true)
  end
end
