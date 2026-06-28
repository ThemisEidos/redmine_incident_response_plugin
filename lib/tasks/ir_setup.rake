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
      'IOC',
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
