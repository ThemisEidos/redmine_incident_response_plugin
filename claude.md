# Redmine Incident Response Plugin

## Stack

- Ruby on Rails (Redmine 6.1.2 plugin)
- Plugin name: redmine_incident_response
- Tests: standalone minitest + activesupport in test/standalone/ (no Redmine instance needed)

## Current Phase

Phase 4 per plugin_roadmap.txt — workflow engine (escalation chain, status map) complete;
Phases 5–7 (data import, command dashboard, intel layer) not started.
Active plan: docs/superpowers/plans/2026-07-07-audit-remediation-and-completion.md

## Key Conventions

- Never modify Redmine core
- All logic via plugin hooks and patches
- No new DB tables; issues + custom fields are the universal data container
- Vernacular tracker names come from lib/redmine_incident_response/vernacular.rb — exact strings

## Docs

See docs/ for SOP, role definitions, templates, and roadmap.
See README.md for setup and required custom fields.
