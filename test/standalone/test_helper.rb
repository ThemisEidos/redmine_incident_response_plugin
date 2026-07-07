require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext'

# Minimal stand-ins for the Redmine AR objects the plugin logic reads.
StubCustomField = Struct.new(:name)
StubCustomFieldValue = Struct.new(:custom_field, :value)
StubTracker = Struct.new(:name)
StubStatus = Struct.new(:name)
StubPriority = Struct.new(:name)

class StubIssue
  attr_accessor :id, :subject, :tracker, :status, :priority, :project, :custom_field_values

  def initialize(id: 1, subject: '', tracker: nil, status: nil, priority: nil, project: nil, fields: {})
    @id = id
    @subject = subject
    @tracker = tracker
    @status = status
    @priority = priority
    @project = project
    @custom_field_values = fields.map do |name, value|
      StubCustomFieldValue.new(StubCustomField.new(name), value)
    end
  end

  def save
    true
  end
end

ROOT = File.expand_path('../..', __dir__)
require File.join(ROOT, 'lib/redmine_incident_response')
require File.join(ROOT, 'lib/redmine_incident_response/vernacular')
require File.join(ROOT, 'lib/redmine_incident_response/field_lookup')
require File.join(ROOT, 'lib/redmine_incident_response/models/ir_context')
require File.join(ROOT, 'lib/redmine_incident_response/models/ir_status_map')
require File.join(ROOT, 'lib/redmine_incident_response/models/loe_context')
require File.join(ROOT, 'lib/redmine_incident_response/models/validation_chain')
require File.join(ROOT, 'lib/redmine_incident_response/ontology')
require File.join(ROOT, 'lib/redmine_incident_response/context')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/classifier')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/transition_guard')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/issue_presenter')
require File.join(ROOT, 'lib/redmine_incident_response/issue_patch')
require File.join(ROOT, 'lib/redmine_incident_response/quick_action_service')
