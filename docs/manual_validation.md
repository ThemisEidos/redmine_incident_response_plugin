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

## 2026-07-07 live validation (in progress, partial)

Deployed `fix/audit-remediation` (HEAD `c40d4a9`) to the live Redmine 6.1.2 host.

**Host:** `164.92.127.87`, hostname `ubuntu-s-1vcpu-1gb-sfo3-redmine2`, Redmine root `/root/redmine-6.1`, plugin checked out at `/root/redmine-6.1/plugins/redmine_incident_response`, served by systemd unit `redmine.service` (Puma, port 3000, `RAILS_RELATIVE_URL_ROOT=/redmine2`). Prior to this pass the server had a stale checkout at commit `5887cdb` with uncommitted local hand-edits (an old, pre-remediation dashboard controller/view, and a manually simplified `hooks.rb` that rendered only the basic IR panel — likely a production hotfix for the exact F1 bug this plan fixes). Those edits were preserved via `git stash -u` before checking out the new branch, not discarded.

**Deploy steps run:** `git stash -u` → `git checkout fix/audit-remediation` → `git pull` → `bundle exec rake ir:setup RAILS_ENV=production` (created all 13 vernacular trackers + custom fields, confirmed via Administration → Trackers) → killed a stray manually-started Puma process that predated systemd management → `systemctl enable --now redmine.service`.

**Verified working (Step 2 of plan Task 15):**
- Both panels render on an issue show page: "Incident Response" (basic) and "Incident Response Ontology Panel" (full classification: Detection Type, Lifecycle State, Analyst Lane, Escalation Eligibility, etc.), confirmed on a Bug-tracker issue (`Bug #1`) — all 16 ontology fields show correctly, unset fields degrade to "Not set" as designed, no crash.
- `Lifecycle State` correctly derives from Redmine status via `IrStatusMap` (status "New" → lifecycle "Triage").
- Quick Actions correctly show "None available" for non-IR trackers (Bug, Feature) — the Task 3 tracker-scoping fix is working; the panel doesn't offer or attempt IR actions on unrelated issues.
- `rake ir:setup` confirmed idempotent-safe and successfully created all 13 trackers (NAR, IOC, VALIDATED IOC, OBSERVABLE, RFI, SITREP, AAR, LOE, ME, Incident, Evidence Item, Command Update, Analysis Task) — visible in Administration → Trackers.

**Gotcha found (not a plugin bug, an operational step missing from the plan):** `rake ir:setup` creates trackers globally but does NOT enable them on existing projects — Redmine requires each project to individually opt into trackers via Project → Settings → Trackers. A pre-existing project ("temp") didn't have NAR/IOC/etc. available in its new-issue tracker dropdown until this was done manually. **Follow-up for the plan/rake task:** consider whether `ir:setup` should also enable the new trackers on all existing projects, or whether this should just be documented as a required post-setup step.

**Still pending (plan Task 15 steps 3–6):** quick-action buttons on an actual NAR/OBSERVABLE/IOC issue (tracker-enable-on-project fix was just applied, not yet retested), transition-guard validation errors, permission checks (module-disabled / missing `manage_incident_response` / non-admin dashboard access).

**Unrelated finding, explicitly out of scope for this plugin:** the public site `https://nanenanebooboo.com/redmine2/` does NOT point at this host — DNS resolves that domain to `24.144.83.27`, a different server running a separate, much older installation of this same plugin (name/author/version metadata match because those `init.rb` fields were never edited by any of the 15 remediation tasks — this was a red herring, not evidence of stale code). This is a DNS/infrastructure routing question for whoever owns that domain, not a plugin defect. Live verification is proceeding directly against `164.92.127.87:3000/redmine2/`.
