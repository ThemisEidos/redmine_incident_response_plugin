require_relative 'lib/redmine_incident_response'
require_relative 'lib/redmine_incident_response/ontology'
require_relative 'lib/redmine_incident_response/vernacular'
require_relative 'lib/redmine_incident_response/field_lookup'
require_relative 'lib/redmine_incident_response/models/ir_context'
require_relative 'lib/redmine_incident_response/models/loe_context'
require_relative 'lib/redmine_incident_response/models/ioc'
require_relative 'lib/redmine_incident_response/models/ir_status_map'
require_relative 'lib/redmine_incident_response/models/validation_chain'
require_relative 'lib/redmine_incident_response/ontology/classifier'
require_relative 'lib/redmine_incident_response/ontology/transition_guard'
require_relative 'lib/redmine_incident_response/ontology/issue_presenter'
require_relative 'lib/redmine_incident_response/context'
require_relative 'lib/redmine_incident_response/issue_helper'
require_relative 'lib/redmine_incident_response/issue_patch'
require_relative 'lib/redmine_incident_response/quick_action_service'
require_relative 'lib/redmine_incident_response/hooks'

Redmine::Plugin.register :redmine_incident_response do
  name 'Redmine Incident Response'
  author 'Codex'
  description 'Minimal incident response plugin skeleton for Redmine 6.1.2.'
  version RedmineIncidentResponse::VERSION
  url 'https://example.com'
  author_url 'https://example.com'

  menu :admin_menu,
       :incident_response,
       { controller: 'incident_response', action: 'index' },
       caption: 'Incident Response'

  project_module :incident_response do
    permission :view_incident_response,   { incident_response: [:index] }, read: true
    permission :manage_incident_response, { incident_response: [:index] }
  end
end

Rails.application.config.to_prepare do
  unless Issue.included_modules.include?(RedmineIncidentResponse::IssuePatch)
    Issue.send(:include, RedmineIncidentResponse::IssuePatch)
  end
end
