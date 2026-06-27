# Vernacular Standardization

## Canonical terms

- `LOE` means `Line of Effort`
- `ME` means `Mission Element`
- `NAR` means `Non-Standard Anomaly Report`
- `IOC` means `Indicator of Compromise`
- `Validated IOC` means an IOC confirmed by Tier 2 or Crew Lead validation
- `Observable` means a raw measurable artifact or observation
- `Evidence Reference` means a Redmine reference to evidence, not raw evidence storage
- `SITREP` means `Situation Report`
- `RFI` means `Request for Information`
- `AAR` means `After Action Review`
- `AAR Action Item` means a corrective task or follow-up issue created from the After Action Review

## Definitions

- `Observable`: raw, measurable, or directly observed material
- `NAR`: suspicious or abnormal item that warrants investigation but does not yet meet IOC criteria
- `IOC`: candidate indicator that merits validation before containment decisions
- `Validated IOC`: IOC confirmed by Tier 2 / Crew Lead validation and eligible for containment, eradication, monitoring, SITREP, or escalation
- `Evidence Reference`: issue-linked pointer to evidence already stored elsewhere under approved controls

## Deprecated or forbidden synonyms

- `IOC Alert` is deprecated. Use `IOC Report` if a reporting label is required.
- `Detection Event` is deprecated when it refers to a candidate IOC. Use `IOC`.
- `Finding` is deprecated when it refers to a raw observation. Use `Observable`.
- `Case` is deprecated when it refers to the Redmine incident container. Use `Incident`.
- `Validation Report` is deprecated. Use `IOC Validation`.
- `Confirmed IOC` is deprecated. Use `Validated IOC`.
- `After Action Report` is deprecated unless it is the title of an external document.
- `Raw evidence` must not be used as a Redmine-stored label for incident evidence objects.

## Old-to-new mapping

| Old label | New label | Notes |
| --- | --- | --- |
| IOC Alert | IOC Report | Use only when a report label is needed |
| Detection Event | IOC | Only when the item is a candidate IOC |
| Finding | Observable | Only when the item is a raw observation |
| Case | Incident | Do not use for external Security Onion case references |
| Validation Report | IOC Validation | Validation artifact label |
| Confirmed IOC | Validated IOC | Final validated state |
| After Action Report | After Action Review | Only for canonical terminology; external document titles may retain the old label |

## Lifecycle

Authoritative lifecycle:

`Observable` → `NAR` → `IOC` → `Validated IOC` → `Incident / TTP correlation`

Operational rules:

- `NAR` does not trigger containment
- `NAR` can be investigated and promoted to `IOC`
- `IOC` requires validation
- `Validated IOC` may trigger containment, eradication, monitoring, SITREP, or escalation
- Crew Lead / Tier 2 owns final IOC validation
- Redmine remains the system of record for issue IDs, analyst assignment, validation timestamps, and linked artifacts

## Redmine object mapping

- `Incident` is the Redmine issue container for the incident record
- `LOE` is represented by a parent issue or a custom field group
- `ME` is represented by a Mission Element custom field
- `Observable` is represented by an issue note or supporting field
- `NAR` is represented by tracker `NAR`
- `IOC` is represented by tracker `IOC`
- `Validated IOC` is represented by an `IOC` tracker item with validation status
- `Evidence Reference` is represented by a tracker or custom fields, not raw evidence storage
- `SITREP` is represented by tracker `Command Update` or `SITREP`
- `RFI` is represented by tracker `RFI`
- `AAR` is represented by tracker `After Action Item` or `Lesson Learned`
- `AAR Action Item` is represented by a corrective task or follow-up issue derived from the review

## Role ownership

- Analyst: logs `Observable` and `NAR` items, links evidence references, and escalates candidate IOCs
- Tier 1: triages `NAR` and candidate `IOC` items
- Tier 2 / Crew Lead: performs final `IOC` validation and marks `Validated IOC`
- Incident lead: owns incident coordination, containment decisions, and downstream reporting
- Redmine admin: maintains trackers, custom fields, and issue workflow labels

## UI label rules

- Prefer canonical terms in visible labels and panel headings
- Keep `LOE` and `ME` unchanged
- Prefer `Validated IOC` over `Confirmed IOC`
- Prefer `Observable` over `Finding` when the label means raw observation
- Prefer `Incident` over `Case` unless an external system is explicitly referenced
- Prefer `After Action Review` over `After Action Report`
- Preserve `AAR Action Item` for corrective tasks or follow-up issues
- Use `Evidence Reference` for references only; do not imply raw evidence storage in labels
- Do not introduce new labels that imply raw logs, malware, forensic images, packet captures, or uncontrolled evidence are stored in Redmine
