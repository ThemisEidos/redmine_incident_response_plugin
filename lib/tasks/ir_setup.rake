namespace :ir do
  desc 'Create IR trackers, issue statuses, and roles if they do not already exist'
  task setup: :environment do
    puts "\n== IR Setup =="

    # -----------------------------------------------------------------------
    # Issue Statuses
    # Order matters: closed statuses last so acts_as_list positions look sane.
    # -----------------------------------------------------------------------
    status_definitions = [
      { name: 'New',                is_closed: false },
      { name: 'In Progress',        is_closed: false },
      { name: 'Pending Validation', is_closed: false },
      { name: 'Validated IOC',      is_closed: false },
      { name: 'Escalated',          is_closed: false },
      { name: 'Closed',             is_closed: true  }
    ]

    puts "\n-- Issue Statuses --"
    status_definitions.each do |defn|
      if IssueStatus.exists?(name: defn[:name])
        puts "  [skip]    #{defn[:name]}"
      else
        status = IssueStatus.new(name: defn[:name], is_closed: defn[:is_closed])
        if status.save
          puts "  [created] #{defn[:name]}"
        else
          puts "  [ERROR]   #{defn[:name]}: #{status.errors.full_messages.join(', ')}"
        end
      end
    end

    # -----------------------------------------------------------------------
    # Trackers
    # Trackers require a default_status_id; use "New" as the seed default.
    # -----------------------------------------------------------------------
    tracker_names = [
      'Incident',
      'NAR',
      'IOC',
      'VALIDATED IOC',
      'OBSERVABLE',
      'RFI',
      'SITREP',
      'AAR',
      'LOE',
      'ME',
      'Evidence Item',
      'Command Update',
      'Analysis Task'
    ]

    puts "\n-- Trackers --"
    default_status = IssueStatus.find_by(name: 'New')
    if default_status.nil?
      puts "  [ERROR] Cannot create trackers — 'New' status not found. Aborting tracker setup."
    else
      tracker_names.each do |name|
        if Tracker.exists?(name: name)
          puts "  [skip]    #{name}"
        else
          tracker = Tracker.new(
            name: name,
            default_status: default_status,
            is_in_roadmap: false
          )
          if tracker.save
            puts "  [created] #{name}"
          else
            puts "  [ERROR]   #{name}: #{tracker.errors.full_messages.join(', ')}"
          end
        end
      end
    end

    # -----------------------------------------------------------------------
    # Custom Fields (README "Required custom field names")
    # -----------------------------------------------------------------------
    field_definitions = [
      { name: 'Detection Type', format: 'list',
        possible_values: ['NAR', 'IOC', 'VALIDATED IOC', 'OBSERVABLE', 'RFI', 'LOE', 'ME', 'Operational Objective'] },
      { name: 'Lifecycle State', format: 'list',
        possible_values: ['NAR', 'IOC', 'Pending Validation', 'VALIDATED IOC', 'Under Investigation',
                          'RFI Open', 'LOE Active', 'ME Active', 'Operational Objective Active', 'Escalated', 'Closed'] },
      { name: 'Analyst Lane', format: 'list',
        possible_values: ['CTI', 'Host', 'Network', 'Forensics'] },
      { name: 'Validation Disposition', format: 'list',
        possible_values: ['VERIFIED', 'FALSE POSITIVE', 'UNDER INVESTIGATION'] },
      { name: 'IR Severity', format: 'list',
        possible_values: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] },
      { name: 'IR Status', format: 'list',
        possible_values: ['New', 'Triage', 'Analysis', 'Containment', 'Recovery', 'Closed'] },
      { name: 'Validation Rationale',           format: 'text'   },
      { name: 'Directed Actions',               format: 'text'   },
      { name: 'Target Assets',                  format: 'text'   },
      { name: 'Evidence Reference',             format: 'text'   },
      { name: 'Reviewer / Validator',           format: 'string' },
      { name: 'MITRE ATT&CK Tactic',            format: 'string' },
      { name: 'MITRE ATT&CK Technique',         format: 'string' },
      { name: 'TTP Tags',                       format: 'string' },
      { name: 'Cross-Incident Correlation ID',  format: 'string' },
      { name: 'Threat Actor Tags',              format: 'string' },
      { name: 'Blast Radius',                   format: 'string' },
      { name: 'Operational Impact',             format: 'string' },
      { name: 'LOE',                            format: 'string' }
    ]

    puts "\n-- Custom Fields --"
    ir_trackers = Tracker.where(name: tracker_names)
    field_definitions.each do |defn|
      if IssueCustomField.exists?(name: defn[:name])
        puts "  [skip]    #{defn[:name]}"
        next
      end

      field = IssueCustomField.new(
        name: defn[:name],
        field_format: defn[:format],
        is_for_all: true,
        is_filter: true
      )
      field.possible_values = defn[:possible_values] if defn[:possible_values]
      field.trackers = ir_trackers

      if field.save
        puts "  [created] #{defn[:name]}"
      else
        puts "  [ERROR]   #{defn[:name]}: #{field.errors.full_messages.join(', ')}"
      end
    end

    # -----------------------------------------------------------------------
    # Roles
    # -----------------------------------------------------------------------
    role_definitions = [
      { name: 'Commander',           issues_visibility: 'all'     },
      { name: 'Team Lead',           issues_visibility: 'all'     },
      { name: 'Mission Element Lead', issues_visibility: 'default' },
      { name: 'Crew Lead',           issues_visibility: 'default' },
      { name: 'Operator',            issues_visibility: 'default' },
      { name: 'Intel Analyst',       issues_visibility: 'default' },
      { name: 'Observer',            issues_visibility: 'own'     }
    ]

    puts "\n-- Roles --"
    role_definitions.each do |defn|
      if Role.exists?(name: defn[:name])
        puts "  [skip]    #{defn[:name]}"
      else
        role = Role.new(
          name: defn[:name],
          assignable: true,
          issues_visibility: defn[:issues_visibility],
          time_entries_visibility: 'own',
          permissions: []
        )
        if role.save
          puts "  [created] #{defn[:name]}"
        else
          puts "  [ERROR]   #{defn[:name]}: #{role.errors.full_messages.join(', ')}"
        end
      end
    end

    puts "\n== IR Setup complete ==\n\n"
  end
end
