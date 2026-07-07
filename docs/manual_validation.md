# Manual Validation Notes

Use this checklist against a live Redmine 6.1.2 instance.

## Runtime checks

1. Open an issue show page.
2. Confirm the Incident Response Ontology Panel renders once.
3. Confirm missing custom fields do not crash the page.
4. Confirm the panel shows `Not set` when fields are absent.
5. Confirm `NAR` issues render a non-authoritative lifecycle state.
6. Confirm `IOC` issues render `Requires Validation`.
7. Confirm `VALIDATED IOC` requires disposition and validator identity.
8. Confirm `OBSERVABLE` cannot jump directly to `VALIDATED IOC`.
9. Confirm `FALSE POSITIVE` is not escalation eligible.

## Hook checks

1. Verify `view_issues_show_details_bottom` injects the ontology panel.
2. Verify the compatibility partial delegates to `hooks/redmine_incident_response/_issue_ontology_panel`.
3. Verify controller hook methods do not attempt recursive saves.

## Environment notes

- No database tables are added.
- No Redmine core files are modified.
- Ruby syntax was not validated locally because `ruby` is unavailable on this machine PATH.
