module RedmineIncidentResponse
  module Models
    IrContext = Struct.new(:incident_id, :severity, :analyst_lane, :ir_status, keyword_init: true)
  end
end
