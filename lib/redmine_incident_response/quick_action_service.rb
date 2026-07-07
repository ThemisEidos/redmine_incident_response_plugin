module RedmineIncidentResponse
  module QuickActionService
    module_function

    def perform(issue, action_key, user)
      issue.init_journal(user) if issue.respond_to?(:init_journal)

      case action_key
      when 'promote_nar_to_ioc', 'convert_observable_to_ioc'
        change_tracker(issue, Vernacular::IOC)
      when 'convert_to_rfi'
        change_tracker(issue, Vernacular::RFI)
      when 'submit_for_validation'
        set_custom_field(issue, 'Lifecycle State', 'Pending Validation')
      when 'escalate'
        escalate(issue, user)
      else
        { success: false, message: "Unknown quick action: #{action_key}" }
      end
    end

    def change_tracker(issue, tracker_name)
      tracker = Tracker.find_by(name: tracker_name)
      return { success: false, message: "Tracker '#{tracker_name}' is not configured in Redmine." } unless tracker

      issue.tracker = tracker
      if issue.save
        { success: true, message: "Tracker changed to #{tracker_name}." }
      else
        { success: false, message: issue.errors.full_messages.join('; ') }
      end
    end
    private_class_method :change_tracker

    def set_custom_field(issue, field_name, value)
      cfv = issue.custom_field_values.find { |v| v.custom_field&.name == field_name }
      return { success: false, message: "Custom field '#{field_name}' is not configured on this issue." } unless cfv

      cfv.value = value
      if issue.save
        { success: true, message: "#{field_name} set to #{value}." }
      else
        { success: false, message: issue.errors.full_messages.join('; ') }
      end
    end
    private_class_method :set_custom_field

    def escalate(issue, user)
      role_name = escalation_role_for(issue, user)
      chain = Models::ValidationChain.escalate(issue, role_name)
      unless chain[:escalatable]
        return { success: false, message: "No escalation step above #{role_name}." }
      end

      result = set_custom_field(issue, 'Lifecycle State', 'Escalated')
      return result unless result[:success]

      { success: true, message: "Escalated from #{role_name} toward #{chain[:next_role]}." }
    end
    private_class_method :escalate

    def escalation_role_for(issue, user)
      return Models::ValidationChain::ROLES.first unless user.respond_to?(:roles_for_project)

      names = user.roles_for_project(issue.project).map(&:name)
      Models::ValidationChain::ROLES.reverse.find { |role| names.include?(role) } ||
        Models::ValidationChain::ROLES.first
    end
    private_class_method :escalation_role_for
  end
end
