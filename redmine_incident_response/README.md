# Redmine Incident Response Vernacular Layer

This plugin uses Redmine issues as the primary incident container and adds a semantic ontology layer for cyber incident response workflows.
It standardizes the local vocabulary around NAR, IOC, Validated IOC, Observable, Evidence Reference, SITREP, RFI, AAR, LOE, and ME.
`AAR` means `After Action Review`.

## Core ontology labels

- `NAR`
- `IOC`
- `VALIDATED IOC`
- `OBSERVABLE`
- `RFI`
- `SITREP`
- `AAR`
- `LOE`
- `ME`
- `Operational Objective`

## Issue page panel

The issue show page renders an ontology panel through the `view_issues_show_details_bottom` hook.

The panel displays:

- Detection Type
- Lifecycle State
- Analyst Lane
- Escalation Eligibility
- Validation Disposition
- Operational Impact
- Blast Radius
- Evidence Reference
- MITRE ATT&CK Tactic
- MITRE ATT&CK Technique
- Threat Actor Tags
- Cross-Incident Correlation ID
- Validation Rationale
- Directed Actions
- Reviewer / Validator
- Target Assets
- TTP Tags

## Transition guidance

- `NAR` cannot be promoted directly to `VALIDATED IOC`
- `OBSERVABLE` cannot be promoted directly to `VALIDATED IOC`
- `VALIDATED IOC` requires validation disposition
- `VALIDATED IOC` requires validation rationale unless marked `UNDER INVESTIGATION`
- `FALSE POSITIVE` makes escalation ineligible

## Storage model

- No database tables are added
- No ActiveRecord models are used
- Ontology data is derived from issue fields, custom fields, tracker names, and safe defaults
- Raw evidence stays out of Redmine; only evidence references should be stored in fields or notes

## Verification Status

### Static checks performed

- Inspected `init.rb` load order and dependency paths
- Inspected hook registration and partial path wiring
- Inspected ontology classifier, transition guard, and issue presenter
- Verified the ontology panel partial delegates through the compatibility wrapper
- Checked for recursive save calls in the plugin Ruby files

### Ruby syntax check

- Not completed locally because `ruby` is not available on this machine PATH

### Live Redmine runtime check

- Not completed in this environment

### Known limitations

- Controller hook behavior has not been verified against a live Redmine 6.1.2 instance
- The plugin assumes the expected custom fields exist when available, but degrades to `Not set` when they do not
- No persistence layer is added for ontology data

### Required custom field names

- `Detection Type`
- `Lifecycle State`
- `Analyst Lane`
- `Validation Disposition`
- `Validation Rationale`
- `Reviewer / Validator`
- `Operational Impact`
- `Blast Radius`
- `Evidence Reference`
- `MITRE ATT&CK Tactic`
- `MITRE ATT&CK Technique`
- `TTP Tags`
- `Cross-Incident Correlation ID`
- `Threat Actor Tags`
- `Directed Actions`
- `Target Assets`

### Recommended next live validation steps

1. Open an issue show page in Redmine 6.1.2 and confirm the Incident Response Ontology Panel renders.
2. Create issues with missing custom fields and confirm the panel renders `Not set` safely.
3. Validate the `view_issues_show_details_bottom` hook path on a live Redmine instance.
4. Test NAR, IOC, OBSERVABLE, RFI, and VALIDATED IOC issue classifications manually.
