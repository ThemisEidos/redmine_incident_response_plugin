# Redmine Incident Response Vernacular Layer

This plugin uses Redmine issues as the primary incident container and adds a semantic ontology layer for cyber incident response workflows.
It standardizes the local vocabulary around NAR, IOC, Validated IOC, Observable, Evidence Reference, SITREP, RFI, AAR, LOE, and ME.
`AAR` means `After Action Review`.

## Current Plan (2026-07-07)

A security/functionality/efficiency audit was completed on 2026-07-07. Remediation and
Phase 4 completion work is specified task-by-task in
[`docs/superpowers/plans/2026-07-07-audit-remediation-and-completion.md`](docs/superpowers/plans/2026-07-07-audit-remediation-and-completion.md).

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
Quick actions (Promote NAR → IOC, Convert OBSERVABLE → IOC/RFI, Convert NAR → RFI, Submit IOC for Validation, Escalate) render as buttons in the panel and POST to the plugin's quick_action endpoint. They require the project's Incident Response module to be enabled and the manage_incident_response permission.

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

## Setup

1. Install the plugin into `plugins/redmine_incident_response` and restart Redmine.
2. Run `bundle exec rake ir:setup RAILS_ENV=production` from the Redmine root — creates IR statuses, trackers, roles, and all required custom fields (idempotent).
3. Enable the **Incident Response** module on each IR project (Project → Settings → Modules).
4. Grant `view_incident_response` / `manage_incident_response` to the appropriate roles.
5. Optional: seed the training lab with `Initialize-RedmineCyberIRLab.ps1` (set `REDMINE_API_KEY` first).

Ops note: the current deployment target (`/root/redmine-6.1`) should migrate to an
unprivileged service account (e.g. `/opt/redmine`, user `redmine`).

## Testing

Standalone logic tests (no Redmine needed): `gem install activesupport minitest`, then
`for f in test/standalone/*_test.rb; do ruby "$f" || exit 1; done` from the plugin root.

Live verification checklist: see Task 15 in
`docs/superpowers/plans/2026-07-07-audit-remediation-and-completion.md`.
