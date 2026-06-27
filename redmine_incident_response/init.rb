require_dependency 'redmine_incident_response'
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/ontology')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/vernacular')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/models/ir_context')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/models/loe_context')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/models/ioc')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/models/ir_status_map')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/models/validation_chain')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/ontology/classifier')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/ontology/transition_guard')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/ontology/issue_presenter')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/context')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/issue_helper')
require_dependency File.join(File.dirname(__FILE__), 'lib/redmine_incident_response/hooks')

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
end
