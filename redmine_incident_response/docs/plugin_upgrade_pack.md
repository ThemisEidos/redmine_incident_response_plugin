# Vernacular Standardization Upgrade Pack

## Purpose

This upgrade pack standardizes the local Redmine Incident Response plugin vocabulary before the first GitHub commit.

The goal is to align plugin language with the operational model:

`Observable` → `NAR` → `IOC` → `Validated IOC` → `Incident / TTP correlation`

It also keeps Redmine as the system of record for issue tracking, analyst ownership, validation timestamps, and linked artifacts.

## Files changed

- [`/redmine_incident_response/docs/vernacular_standard.md`](/redmine_incident_response/docs/vernacular_standard.md)
- [`/redmine_incident_response/docs/redmine_object_mapping.md`](/redmine_incident_response/docs/redmine_object_mapping.md)
- [`/redmine_incident_response/docs/plugin_upgrade_pack.md`](/redmine_incident_response/docs/plugin_upgrade_pack.md)
- [`/redmine_incident_response/lib/redmine_incident_response/vernacular.rb`](/redmine_incident_response/lib/redmine_incident_response/vernacular.rb)
- [`/redmine_incident_response/init.rb`](/redmine_incident_response/init.rb)
- [`/redmine_incident_response/lib/redmine_incident_response/ontology/classifier.rb`](/redmine_incident_response/lib/redmine_incident_response/ontology/classifier.rb)
- [`/redmine_incident_response/lib/redmine_incident_response/ontology/transition_guard.rb`](/redmine_incident_response/lib/redmine_incident_response/ontology/transition_guard.rb)
- [`/redmine_incident_response/app/views/hooks/redmine_incident_response/_issue_ontology_panel.html.erb`](/redmine_incident_response/app/views/hooks/redmine_incident_response/_issue_ontology_panel.html.erb)
- [`/redmine_incident_response/app/views/incident_response/index.html.erb`](/redmine_incident_response/app/views/incident_response/index.html.erb)
- [`/redmine_incident_response/README.md`](/redmine_incident_response/README.md)

## Files intentionally not changed

- Redmine core files
- Database migrations
- ActiveRecord models
- Controller overrides
- Workflow enforcement logic
- Existing storage abstractions that do not directly conflict with the terminology standard

## Migration-free approach

- The upgrade pack is documentation-first
- Canonical labels are exposed through a pure Ruby constants module
- No schema changes are introduced
- No database writes are required
- No new ActiveRecord-backed persistence is added
- No containment or validation workflow is enforced yet

## First-commit readiness checklist

- [x] Canonical terminology documented
- [x] Deprecated synonyms mapped to preferred labels
- [x] NAR lifecycle documented
- [x] IOC lifecycle documented
- [x] Validated IOC lifecycle documented
- [x] Redmine object mapping documented
- [x] Role ownership rules documented
- [x] UI label rules documented
- [x] Canonical Ruby constants added without database access
- [x] Existing UI labels updated only where safe
- [x] No Redmine core files modified
- [x] No migrations added
- [x] No ActiveRecord models added
- [x] No controller overrides added

## Redmine deployment checklist for later

1. Confirm the target Redmine instance has the expected trackers: `Incident`, `NAR`, `IOC`, `RFI`, `SITREP`, and `AAR` after-action review artifacts, or their local equivalents.
2. Confirm custom fields exist for `LOE`, `ME`, `Observable`, and `Evidence Reference` if the installation uses custom field-based mapping.
3. Confirm analysts understand that `Evidence Reference` points to controlled evidence, not raw evidence storage.
4. Confirm Tier 2 / Crew Lead validation ownership for `Validated IOC`.
5. Confirm tracker and label names align with the incident response playbook before enabling operational use.

## Self-audit

- No Redmine core files modified
- No migrations added
- No ActiveRecord models added
- No controller overrides added
- NAR language added
- IOC language standardized
- Validated IOC language standardized
- AAR canonicalized to After Action Review
- LOE preserved
- ME preserved
- Evidence references separated from raw evidence
- Ready for first GitHub commit: YES
