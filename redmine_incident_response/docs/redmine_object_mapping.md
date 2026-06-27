# Redmine Object Mapping

| IR term | Redmine mapping | Notes |
| --- | --- | --- |
| Incident | Issue / tracker: `Incident` | Primary incident container |
| LOE | Parent issue or custom field group | Preserve term unchanged |
| ME | Mission Element custom field | Preserve term unchanged |
| Observable | Issue note or supporting field | Raw observation only |
| NAR | Tracker: `NAR` | Lower than IOC |
| IOC | Tracker: `IOC` | Candidate indicator requiring validation |
| Validated IOC | `IOC` with validation status | Final validated state owned by Tier 2 / Crew Lead |
| Evidence Reference | Tracker or custom fields | Do not store raw evidence in Redmine |
| SITREP | Tracker: `Command Update` or `SITREP` | Operational update artifact |
| RFI | Tracker: `RFI` | Request for Information |
| AAR | Tracker: `After Action Item` or `Lesson Learned` | `AAR` means `After Action Review`; preserve tracker names |

## Mapping notes

- Redmine remains the system of record for issue IDs, analyst assignment, validation timestamps, and linked artifacts
- Evidence references should point to approved storage locations or linked artifacts, not raw evidence payloads
- NAR is investigative and does not trigger containment
- IOC requires validation before it becomes operationally authoritative
- Validated IOC can drive containment, eradication, monitoring, SITREP creation, or escalation
- LOE and ME are organizational labels and should remain stable across issue lifecycles
- AAR Action Items are corrective tasks or follow-up issues produced by the After Action Review
