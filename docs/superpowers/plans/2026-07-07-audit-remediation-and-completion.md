# Audit Remediation & Project Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every finding from the 2026-07-07 security/functionality/efficiency audit, then bring the plugin to "Phase 4 complete" per `plugin_roadmap.txt` — a working, permission-correct IR ontology layer with a reachable quick-actions UI, an escalation chain, and a one-command environment setup.

**Architecture:** The plugin stays a pure hook/patch layer over Redmine 6.1.2 — no core modifications, no new DB tables; all IR data lives in issue custom fields and tracker names. Remediation consolidates duplicated field/normalization helpers into one `FieldLookup` module, makes classification single-pass, scopes the global Issue validation to IR trackers, and hardens the quick-action endpoint. Completion extends the existing `ir:setup` rake task to provision the full vernacular (trackers + custom fields), wires the ontology panel into the issue page hook, and implements the Phase 4 escalation action.

**Tech Stack:** Ruby ≥ 3.1, Rails (Redmine 6.1.2 plugin API), ERB views, minitest + activesupport for standalone tests, Bash (deploy), PowerShell 5+ (lab seeder).

## Global Constraints

- Repository root: `/mnt/d/D_Projects/08_Redmine/redmine_incident_response_plugin` (git repo, branch `main`). All paths below are relative to it unless absolute.
- Create and work on branch `fix/audit-remediation` off `main`: `git checkout -b fix/audit-remediation`.
- **Never modify Redmine core.** Plugin hooks, patches, and rake tasks only (`plugin_roadmap.txt` "SYSTEM PRINCIPLES").
- **No new database tables or ActiveRecord models.** Custom fields and tracker names are the only storage (README "Storage model").
- Tracker/vernacular names are exact strings from `lib/redmine_incident_response/vernacular.rb`: `NAR`, `IOC`, `VALIDATED IOC`, `OBSERVABLE`, `LOE`, `ME`, `Evidence Reference`, `SITREP`, `RFI`, `AAR`, plus `Incident`.
- Standalone tests run with plain Ruby from the repo root: `ruby test/standalone/<file>.rb`. They need the `activesupport` and `minitest` gems (`gem install activesupport minitest` once). No Redmine instance required.
- This development machine has no live Redmine. Anything marked **[LIVE]** runs on the Redmine host (Redmine root `/root/redmine-6.1`, deployed via `deploy.sh`) and is deferred to Task 15 if no host is reachable — note the deferral in the commit message.
- Commit after every task with conventional-commit messages. End every commit message with the `Co-Authored-By: Claude` trailer already configured for this environment.
- Audit finding IDs referenced below (S=security, F=functionality, E=efficiency) come from the 2026-07-07 audit summarized at the bottom of this file.

---

## Part A — Audit Remediation

### Task 1: Standalone test harness + `FieldLookup` module

Fixes: groundwork for E1/E4 (duplicated `custom_field_value` in 3 modules, duplicated `normalize_compare_value` in 2).

**Files:**
- Create: `test/standalone/test_helper.rb`
- Create: `test/standalone/field_lookup_test.rb`
- Create: `lib/redmine_incident_response/field_lookup.rb`
- Modify: `init.rb` (add one `require_relative`)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `RedmineIncidentResponse::FieldLookup.custom_field_map(issue) -> Hash{String=>value}`, `FieldLookup.custom_field_value(issue, name) -> value|nil`, `FieldLookup.normalize(value) -> String`, `FieldLookup.match?(a, b) -> bool`. Also stub classes `StubIssue`, `StubTracker`, `StubStatus`, `StubPriority`, `StubCustomField`, `StubCustomFieldValue` used by every later test.

- [ ] **Step 1: Verify Ruby environment**

Run: `ruby -v && gem list activesupport minitest | grep -E 'activesupport|minitest'`
Expected: Ruby ≥ 3.1 and both gems listed. If missing: `sudo apt-get install -y ruby-full` (WSL/Debian) then `gem install activesupport minitest --user-install` (add gem user bin/lib to env if needed).

- [ ] **Step 2: Write the test helper with stub objects**

Create `test/standalone/test_helper.rb`:

```ruby
require 'minitest/autorun'
require 'active_support'
require 'active_support/core_ext'

# Minimal stand-ins for the Redmine AR objects the plugin logic reads.
StubCustomField = Struct.new(:name)
StubCustomFieldValue = Struct.new(:custom_field, :value)
StubTracker = Struct.new(:name)
StubStatus = Struct.new(:name)
StubPriority = Struct.new(:name)

class StubIssue
  attr_accessor :id, :subject, :tracker, :status, :priority, :project, :custom_field_values

  def initialize(id: 1, subject: '', tracker: nil, status: nil, priority: nil, project: nil, fields: {})
    @id = id
    @subject = subject
    @tracker = tracker
    @status = status
    @priority = priority
    @project = project
    @custom_field_values = fields.map do |name, value|
      StubCustomFieldValue.new(StubCustomField.new(name), value)
    end
  end

  def save
    true
  end
end

ROOT = File.expand_path('../..', __dir__)
require File.join(ROOT, 'lib/redmine_incident_response')
require File.join(ROOT, 'lib/redmine_incident_response/vernacular')
require File.join(ROOT, 'lib/redmine_incident_response/field_lookup')
require File.join(ROOT, 'lib/redmine_incident_response/models/ir_context')
require File.join(ROOT, 'lib/redmine_incident_response/models/ir_status_map')
require File.join(ROOT, 'lib/redmine_incident_response/models/loe_context')
require File.join(ROOT, 'lib/redmine_incident_response/models/validation_chain')
require File.join(ROOT, 'lib/redmine_incident_response/ontology')
require File.join(ROOT, 'lib/redmine_incident_response/context')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/classifier')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/transition_guard')
require File.join(ROOT, 'lib/redmine_incident_response/ontology/issue_presenter')
require File.join(ROOT, 'lib/redmine_incident_response/issue_patch')
require File.join(ROOT, 'lib/redmine_incident_response/quick_action_service')
```

Note: `ROOT` is computed relative to the helper, so tests run from any CWD. `test/standalone/` must NOT be excluded by `deploy.sh` (it's harmless on the server) — leave rsync excludes alone.

- [ ] **Step 3: Write the failing test**

Create `test/standalone/field_lookup_test.rb`:

```ruby
require_relative 'test_helper'

class FieldLookupTest < Minitest::Test
  FL = RedmineIncidentResponse::FieldLookup

  def test_custom_field_map_builds_name_keyed_hash
    issue = StubIssue.new(fields: { 'Detection Type' => 'IOC', 'Lifecycle State' => 'Pending Validation' })
    map = FL.custom_field_map(issue)
    assert_equal 'IOC', map['Detection Type']
    assert_equal 'Pending Validation', map['Lifecycle State']
  end

  def test_custom_field_map_handles_nil_issue
    assert_equal({}, FL.custom_field_map(nil))
  end

  def test_custom_field_value_reads_single_field
    issue = StubIssue.new(fields: { 'LOE' => 'LOE-ALPHA' })
    assert_equal 'LOE-ALPHA', FL.custom_field_value(issue, 'LOE')
    assert_nil FL.custom_field_value(issue, 'Missing Field')
  end

  def test_normalize_collapses_case_separators_whitespace
    assert_equal 'VALIDATED IOC', FL.normalize('  validated_ioc ')
    assert_equal 'VALIDATED IOC', FL.normalize("Validated-IOC")
    assert_equal '', FL.normalize(nil)
  end

  def test_match_ignores_case_whitespace_and_separators
    assert FL.match?('validated_ioc', 'VALIDATED IOC')
    assert FL.match?('  Validated-IOC ', 'VALIDATED IOC')
    refute FL.match?('IOC', 'VALIDATED IOC')
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `ruby test/standalone/field_lookup_test.rb`
Expected: `LoadError` — `cannot load such file ... lib/redmine_incident_response/field_lookup` (the helper requires the not-yet-existing module).

- [ ] **Step 5: Implement `FieldLookup`**

Create `lib/redmine_incident_response/field_lookup.rb`:

```ruby
module RedmineIncidentResponse
  # Single source of truth for reading issue custom fields and for the
  # whitespace/case/separator-insensitive comparisons used across the ontology.
  module FieldLookup
    module_function

    def custom_field_map(issue)
      return {} unless issue&.respond_to?(:custom_field_values)

      issue.custom_field_values.each_with_object({}) do |field_value, map|
        name = field_value.custom_field&.name
        map[name] = field_value.value if name
      end
    end

    def custom_field_value(issue, field_name)
      custom_field_map(issue)[field_name]
    end

    def normalize(value)
      value.to_s.strip.upcase.tr('_-', ' ').gsub(/\s+/, ' ')
    end

    def match?(value, expected)
      normalize(value) == normalize(expected)
    end
  end
end
```

- [ ] **Step 6: Register in `init.rb`**

In `init.rb`, after the line `require_relative 'lib/redmine_incident_response/vernacular'`, add:

```ruby
require_relative 'lib/redmine_incident_response/field_lookup'
```

- [ ] **Step 7: Run test to verify it passes**

Run: `ruby test/standalone/field_lookup_test.rb`
Expected: `5 runs, 10 assertions, 0 failures, 0 errors`.

- [ ] **Step 8: Commit**

```bash
git add test/standalone/ lib/redmine_incident_response/field_lookup.rb init.rb
git commit -m "feat: add FieldLookup module and standalone test harness"
```

---

### Task 2: Ontology core rewrite — single-pass classification, fixed comparisons, no fabricated data

Fixes: E1 (classifier runs 3–4× per render, 17 linear field scans each), E4 (helper duplication), F3 (inverted "Convert to RFI"), F5 (raw `!=` compare for Submit-for-Validation), F6 (fabricated analyst lane via `issue.id % 4`), plus a newly confirmed bug: `Context.severity_for` maps priority `Urgent`/`Immediate`/`Normal` to the `MEDIUM` default because `normalize_severity` doesn't know Redmine's priority names (the IR panel ERB maps them correctly, so panel and context disagreed).

**Files:**
- Modify (full rewrite): `lib/redmine_incident_response/ontology/classifier.rb`
- Modify (full rewrite): `lib/redmine_incident_response/ontology/transition_guard.rb`
- Modify (full rewrite): `lib/redmine_incident_response/context.rb`
- Modify (full rewrite): `lib/redmine_incident_response/ontology/issue_presenter.rb`
- Modify: `lib/redmine_incident_response/models/loe_context.rb` (use FieldLookup)
- Create: `test/standalone/classifier_test.rb`, `test/standalone/transition_guard_test.rb`, `test/standalone/context_test.rb`

**Interfaces:**
- Consumes: `FieldLookup` (Task 1).
- Produces (later tasks rely on these exact signatures):
  - `Classifier.classify(issue) -> Ontology::PanelContext` (struct unchanged, defined in `lib/redmine_incident_response/ontology.rb`). `panel_context.quick_actions` is an Array of `{ label: String, key: String|nil }`.
  - `TransitionGuard.evaluate(issue, classification: nil) -> TransitionGuard::Result` — pass a precomputed classification to skip re-classifying.
  - `Context.build(issue, fields: nil) -> Models::IrContext` — `analyst_lane` is now `nil` when unset (previously fabricated).
  - `IssuePresenter.panel_locals(issue) -> Hash` with keys `:issue, :ir_context, :ontology, :guard, :loe_context` (unchanged keys; now classifies exactly once).

- [ ] **Step 1: Write the failing tests**

Create `test/standalone/classifier_test.rb`:

```ruby
require_relative 'test_helper'

class ClassifierTest < Minitest::Test
  C = RedmineIncidentResponse::Ontology::Classifier

  def keys_for(issue)
    C.classify(issue).quick_actions.map { |a| a[:key] }
  end

  def test_detection_type_falls_back_to_tracker_name
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    assert_equal 'IOC', C.classify(issue).detection_type
  end

  def test_detection_type_prefers_custom_field_and_normalizes
    issue = StubIssue.new(tracker: StubTracker.new('Bug'), fields: { 'Detection Type' => 'nar' })
    assert_equal 'NAR', C.classify(issue).detection_type
  end

  def test_nar_offers_promote_and_rfi_conversion
    issue = StubIssue.new(tracker: StubTracker.new('NAR'))
    assert_includes keys_for(issue), 'promote_nar_to_ioc'
    assert_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_observable_offers_ioc_and_rfi_conversion
    issue = StubIssue.new(tracker: StubTracker.new('OBSERVABLE'))
    assert_includes keys_for(issue), 'convert_observable_to_ioc'
    assert_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_rfi_issue_gets_no_rfi_conversion
    # F3: the old code offered "Convert to RFI" only when the issue already WAS an RFI.
    issue = StubIssue.new(tracker: StubTracker.new('RFI'))
    refute_includes keys_for(issue), 'convert_to_rfi'
  end

  def test_submit_for_validation_hidden_when_already_validated_regardless_of_case
    # F5: the old code used a raw != compare here.
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Lifecycle State' => 'validated ioc' })
    refute_includes keys_for(issue), 'submit_for_validation'
  end

  def test_ioc_offers_submit_for_validation
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    assert_includes keys_for(issue), 'submit_for_validation'
  end

  def test_verified_ioc_with_rationale_and_validator_is_eligible
    issue = StubIssue.new(
      tracker: StubTracker.new('IOC'),
      fields: {
        'Validation Disposition' => 'VERIFIED',
        'Validation Rationale'   => 'Confirmed via EDR telemetry',
        'Reviewer / Validator'   => 'crew.lead'
      }
    )
    assert_equal 'Eligible', C.classify(issue).escalation_eligibility
  end

  def test_false_positive_is_not_eligible
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Validation Disposition' => 'False Positive' })
    assert_equal 'Not Eligible', C.classify(issue).escalation_eligibility
  end

  def test_unset_analyst_lane_is_nil_not_fabricated
    # F6: the old code assigned a lane from issue.id % 4.
    issue = StubIssue.new(id: 7, tracker: StubTracker.new('IOC'))
    assert_nil C.classify(issue).analyst_lane
  end
end
```

Create `test/standalone/transition_guard_test.rb`:

```ruby
require_relative 'test_helper'

class TransitionGuardTest < Minitest::Test
  TG = RedmineIncidentResponse::Ontology::TransitionGuard

  def test_nar_cannot_jump_to_validated_ioc
    issue = StubIssue.new(tracker: StubTracker.new('NAR'), fields: { 'Lifecycle State' => 'VALIDATED IOC' })
    result = TG.evaluate(issue)
    refute result.allowed
    assert_includes result.messages, 'NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC.'
    assert_equal RedmineIncidentResponse::Vernacular::IOC, result.suggested_lifecycle_state
  end

  def test_validated_ioc_requires_disposition_rationale_and_validator
    issue = StubIssue.new(tracker: StubTracker.new('VALIDATED IOC'))
    result = TG.evaluate(issue)
    refute result.allowed
    assert_equal 3, result.messages.length
  end

  def test_complete_validated_ioc_is_allowed
    issue = StubIssue.new(
      tracker: StubTracker.new('VALIDATED IOC'),
      fields: {
        'Validation Disposition' => 'VERIFIED',
        'Validation Rationale'   => 'Confirmed',
        'Reviewer / Validator'   => 'crew.lead'
      }
    )
    assert TG.evaluate(issue).allowed
  end

  def test_false_positive_produces_notice
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Validation Disposition' => 'FALSE POSITIVE' })
    result = TG.evaluate(issue)
    assert result.allowed
    assert_includes result.notices, 'FALSE POSITIVE: this issue is not eligible for escalation.'
  end

  def test_evaluate_accepts_precomputed_classification
    issue = StubIssue.new(tracker: StubTracker.new('IOC'))
    classification = RedmineIncidentResponse::Ontology::Classifier.classify(issue)
    result = TG.evaluate(issue, classification: classification)
    assert result.allowed
  end
end
```

Create `test/standalone/context_test.rb`:

```ruby
require_relative 'test_helper'

class ContextTest < Minitest::Test
  CTX = RedmineIncidentResponse::Context

  def test_incident_id_format
    assert_equal 'ISSUE-42', CTX.build(StubIssue.new(id: 42)).incident_id
  end

  def test_analyst_lane_nil_when_unset
    assert_nil CTX.build(StubIssue.new(id: 7)).analyst_lane
  end

  def test_analyst_lane_from_custom_field
    assert_equal 'Host', CTX.build(StubIssue.new(fields: { 'Analyst Lane' => 'Host' })).analyst_lane
  end

  def test_severity_from_custom_field_wins
    issue = StubIssue.new(priority: StubPriority.new('Low'), fields: { 'IR Severity' => 'crit' })
    assert_equal 'CRITICAL', CTX.build(issue).severity
  end

  def test_priority_urgent_maps_to_critical
    assert_equal 'CRITICAL', CTX.build(StubIssue.new(priority: StubPriority.new('Urgent'))).severity
  end

  def test_priority_immediate_maps_to_critical
    assert_equal 'CRITICAL', CTX.build(StubIssue.new(priority: StubPriority.new('Immediate'))).severity
  end

  def test_priority_normal_maps_to_medium
    assert_equal 'MEDIUM', CTX.build(StubIssue.new(priority: StubPriority.new('Normal'))).severity
  end

  def test_ir_status_defaults_to_new
    assert_equal 'New', CTX.build(StubIssue.new).ir_status
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/standalone/classifier_test.rb && ruby test/standalone/transition_guard_test.rb && ruby test/standalone/context_test.rb`
Expected: failures — at minimum `test_rfi_issue_gets_no_rfi_conversion`, `test_nar_offers_promote_and_rfi_conversion`, `test_unset_analyst_lane_is_nil_not_fabricated`, `test_analyst_lane_nil_when_unset`, `test_priority_urgent_maps_to_critical`, `test_submit_for_validation_hidden_when_already_validated_regardless_of_case`, and `test_evaluate_accepts_precomputed_classification` (ArgumentError: unknown keyword).

- [ ] **Step 3: Rewrite `context.rb`**

Replace the entire contents of `lib/redmine_incident_response/context.rb` with:

```ruby
module RedmineIncidentResponse
  module Context
    ANALYST_LANES = ['CTI', 'Host', 'Network', 'Forensics'].freeze
    DEFAULT_SEVERITY = 'MEDIUM'
    DEFAULT_STATUS = 'New'

    def self.build(issue, fields: nil)
      fields ||= FieldLookup.custom_field_map(issue)
      issue_id = issue&.id

      Models::IrContext.new(
        incident_id: issue_id ? "ISSUE-#{issue_id}" : nil,
        severity: severity_for(issue, fields),
        analyst_lane: fields['Analyst Lane'].presence&.to_s,
        ir_status: fields['IR Status'].presence&.to_s || DEFAULT_STATUS
      )
    end

    def self.severity_for(issue, fields)
      value = fields['IR Severity']
      return normalize_severity(value) if value.present?

      priority_name = issue&.priority&.name
      return normalize_severity(priority_name) if priority_name.present?

      DEFAULT_SEVERITY
    end

    def self.normalize_severity(value)
      case value.to_s.strip.upcase
      when 'LOW', 'L'                              then 'LOW'
      when 'MEDIUM', 'MED', 'M', 'NORMAL'          then 'MEDIUM'
      when 'HIGH', 'H'                             then 'HIGH'
      when 'CRITICAL', 'CRIT', 'URGENT', 'IMMEDIATE' then 'CRITICAL'
      else DEFAULT_SEVERITY
      end
    end
    private_class_method :normalize_severity
  end
end
```

Deliberate behavior changes: analyst lane is `nil` when unset (the panel renders it as "Not set"); Redmine priority names `Normal`/`Urgent`/`Immediate` now map correctly.

- [ ] **Step 4: Rewrite `classifier.rb`**

Replace the entire contents of `lib/redmine_incident_response/ontology/classifier.rb` with:

```ruby
module RedmineIncidentResponse
  module Ontology
    module Classifier
      DETECTION_TYPE_MAP = {
        'NAR' => RedmineIncidentResponse::Vernacular::NAR,
        'IOC' => RedmineIncidentResponse::Vernacular::IOC,
        'VALIDATED IOC' => RedmineIncidentResponse::Vernacular::VALIDATED_IOC,
        'OBSERVABLE' => RedmineIncidentResponse::Vernacular::OBSERVABLE,
        'RFI' => RedmineIncidentResponse::Vernacular::RFI,
        'LOE' => RedmineIncidentResponse::Vernacular::LOE,
        'ME' => RedmineIncidentResponse::Vernacular::ME,
        'OPERATIONAL OBJECTIVE' => 'Operational Objective'
      }.freeze

      module_function

      def classify(issue)
        fields = FieldLookup.custom_field_map(issue)
        incident_context = Context.build(issue, fields: fields)

        detection_type = detection_type_for(issue, fields)
        lifecycle_state = lifecycle_state_for(issue, fields, detection_type)

        validation_disposition = fields['Validation Disposition']
        validation_rationale = fields['Validation Rationale']
        validator_identity = fields['Reviewer / Validator']

        escalation_eligibility = escalation_eligibility_for(
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          validation_disposition: validation_disposition,
          validation_rationale: validation_rationale,
          validator_identity: validator_identity
        )

        PanelContext.new(
          incident_id: incident_context.incident_id,
          detection_type: detection_type,
          lifecycle_state: lifecycle_state,
          analyst_lane: fields['Analyst Lane'].presence || incident_context.analyst_lane,
          escalation_eligibility: escalation_eligibility,
          validation_disposition: validation_disposition,
          operational_impact: fields['Operational Impact'],
          blast_radius: fields['Blast Radius'],
          evidence_reference: fields[RedmineIncidentResponse::Vernacular::EVIDENCE_REFERENCE],
          mitre_tactic: fields['MITRE ATT&CK Tactic'],
          mitre_technique: fields['MITRE ATT&CK Technique'],
          ttp_tags: fields['TTP Tags'],
          cross_incident_correlation_id: fields['Cross-Incident Correlation ID'],
          threat_actor_tags: fields['Threat Actor Tags'],
          validation_rationale: validation_rationale,
          directed_actions: fields['Directed Actions'],
          validator_identity: validator_identity,
          target_assets: fields['Target Assets'],
          quick_actions: quick_actions_for(
            detection_type: detection_type,
            lifecycle_state: lifecycle_state,
            escalation_eligibility: escalation_eligibility
          ),
          messages: []
        )
      end

      def display_text(value)
        value.present? ? value : 'Not set'
      end

      def detection_type_for(issue, fields = nil)
        fields ||= FieldLookup.custom_field_map(issue)
        raw = fields['Detection Type'].presence || issue&.tracker&.name.to_s.strip
        normalized = FieldLookup.normalize(raw)
        return nil if normalized.blank?

        DETECTION_TYPE_MAP[normalized] || normalized
      end

      def lifecycle_state_for(issue, fields = nil, detection_type = nil)
        fields ||= FieldLookup.custom_field_map(issue)
        detection_type ||= detection_type_for(issue, fields)

        fields['Lifecycle State'].presence ||
          default_lifecycle_state_for(detection_type, issue) ||
          'Not set'
      end

      def escalation_eligibility_for(detection_type:, lifecycle_state:, validation_disposition:, validation_rationale:, validator_identity:)
        return 'Not Eligible' if FieldLookup.match?(validation_disposition, 'FALSE POSITIVE')
        return 'Requires Validation' if FieldLookup.match?(validation_disposition, 'UNDER INVESTIGATION')
        return 'Blocked' if invalid_direct_validation?(detection_type, lifecycle_state)

        if FieldLookup.match?(validation_disposition, 'VERIFIED') &&
           validation_rationale.present? &&
           validator_identity.present?
          'Eligible'
        elsif requires_validation_type?(detection_type)
          'Requires Validation'
        else
          'Not Set'
        end
      end

      def quick_actions_for(detection_type:, lifecycle_state:, escalation_eligibility:)
        actions = []

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::NAR)
          actions << { label: 'Promote NAR → IOC', key: 'promote_nar_to_ioc' }
          actions << { label: 'Convert NAR → RFI', key: 'convert_to_rfi' }
        end

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)
          actions << { label: 'Convert OBSERVABLE → IOC', key: 'convert_observable_to_ioc' }
          actions << { label: 'Convert OBSERVABLE → RFI', key: 'convert_to_rfi' }
        end

        if FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::IOC) &&
           !FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
          actions << { label: 'Submit IOC for Validation', key: 'submit_for_validation' }
        end

        if FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::IOC) ||
           FieldLookup.match?(lifecycle_state, 'Pending Validation')
          actions << { label: 'Validate IOC', key: nil }
        end

        if FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC) &&
           escalation_eligibility == 'Eligible'
          actions << { label: 'Escalate to Crew Lead', key: nil }
        end

        actions
      end

      def requires_validation_type?(detection_type)
        [
          RedmineIncidentResponse::Vernacular::NAR,
          RedmineIncidentResponse::Vernacular::OBSERVABLE,
          RedmineIncidentResponse::Vernacular::IOC
        ].any? { |type| FieldLookup.match?(detection_type, type) }
      end
      private_class_method :requires_validation_type?

      def default_lifecycle_state_for(detection_type, issue)
        case FieldLookup.normalize(detection_type)
        when 'NAR'                   then RedmineIncidentResponse::Vernacular::NAR
        when 'IOC'                   then RedmineIncidentResponse::Vernacular::IOC
        when 'VALIDATED IOC'         then RedmineIncidentResponse::Vernacular::VALIDATED_IOC
        when 'OBSERVABLE'            then 'Under Investigation'
        when 'RFI'                   then 'RFI Open'
        when 'LOE'                   then 'LOE Active'
        when 'ME'                    then 'ME Active'
        when 'OPERATIONAL OBJECTIVE' then 'Operational Objective Active'
        else
          Models::IrStatusMap.lifecycle_for(issue&.status&.name) || 'Not set'
        end
      end
      private_class_method :default_lifecycle_state_for

      def invalid_direct_validation?(detection_type, lifecycle_state)
        (FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::NAR) ||
         FieldLookup.match?(detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          FieldLookup.match?(lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :invalid_direct_validation?
    end
  end
end
```

Note: "Escalate to Crew Lead" keeps `key: nil` here — it becomes an executable action in Task 12.

- [ ] **Step 5: Rewrite `transition_guard.rb`**

Replace the entire contents of `lib/redmine_incident_response/ontology/transition_guard.rb` with:

```ruby
module RedmineIncidentResponse
  module Ontology
    module TransitionGuard
      Result = Struct.new(
        :allowed,
        :suggested_lifecycle_state,
        :messages,
        :notices,
        :normalized_detection_type,
        :normalized_lifecycle_state,
        keyword_init: true
      )

      module_function

      def evaluate(issue, classification: nil)
        classification ||= Classifier.classify(issue)
        messages = []
        notices = []
        suggested_lifecycle_state = classification.lifecycle_state

        if direct_validation_blocked?(classification)
          messages << 'NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC.'
          suggested_lifecycle_state = RedmineIncidentResponse::Vernacular::IOC
        end

        if FieldLookup.match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
          if classification.validation_disposition.to_s.strip.empty?
            messages << 'VALIDATED IOC requires a Validation Disposition.'
          end

          if classification.validation_rationale.to_s.strip.empty? &&
             !FieldLookup.match?(classification.validation_disposition, 'UNDER INVESTIGATION')
            messages << 'VALIDATED IOC requires a Validation Rationale unless disposition is UNDER INVESTIGATION.'
          end

          if classification.validator_identity.to_s.strip.empty?
            messages << 'VALIDATED IOC requires a Reviewer / Validator.'
          end
        end

        if FieldLookup.match?(classification.validation_disposition, 'FALSE POSITIVE')
          notices << 'FALSE POSITIVE: this issue is not eligible for escalation.'
        end

        Result.new(
          allowed: messages.empty?,
          suggested_lifecycle_state: suggested_lifecycle_state,
          messages: messages,
          notices: notices,
          normalized_detection_type: classification.detection_type,
          normalized_lifecycle_state: classification.lifecycle_state
        )
      end

      def direct_validation_blocked?(classification)
        (FieldLookup.match?(classification.detection_type, RedmineIncidentResponse::Vernacular::NAR) ||
         FieldLookup.match?(classification.detection_type, RedmineIncidentResponse::Vernacular::OBSERVABLE)) &&
          FieldLookup.match?(classification.lifecycle_state, RedmineIncidentResponse::Vernacular::VALIDATED_IOC)
      end
      private_class_method :direct_validation_blocked?
    end
  end
end
```

- [ ] **Step 6: Rewrite `issue_presenter.rb`**

Replace the entire contents of `lib/redmine_incident_response/ontology/issue_presenter.rb` with:

```ruby
module RedmineIncidentResponse
  module Ontology
    module IssuePresenter
      module_function

      def panel_context(issue, classification: nil, guard: nil)
        classification ||= Classifier.classify(issue)
        guard ||= TransitionGuard.evaluate(issue, classification: classification)

        context = classification.dup
        context.messages = guard.messages
        context
      end

      def panel_locals(issue)
        classification = Classifier.classify(issue)
        guard = TransitionGuard.evaluate(issue, classification: classification)

        {
          issue: issue,
          ir_context: Context.build(issue),
          ontology: panel_context(issue, classification: classification, guard: guard),
          guard: guard,
          loe_context: Models::LoeContext.build(issue)
        }
      end

      def panel_partial
        'hooks/redmine_incident_response/issue_ontology_panel'
      end

      def display_text(value)
        return 'Not set' if value.nil?

        if value.respond_to?(:empty?) && value.empty?
          'Not set'
        elsif value.is_a?(Array)
          value.compact.map(&:to_s).reject(&:empty?).join(', ').presence || 'Not set'
        else
          value.to_s.presence || 'Not set'
        end
      end
    end
  end
end
```

- [ ] **Step 7: Point `LoeContext` at FieldLookup**

In `lib/redmine_incident_response/models/loe_context.rb`, replace the `custom_field_loe` method body with:

```ruby
      def self.custom_field_loe(issue)
        FieldLookup.custom_field_value(issue, DEFAULT_FIELD_NAME).presence
      end
      private_class_method :custom_field_loe
```

- [ ] **Step 8: Run the full standalone suite**

Run: `for f in test/standalone/*_test.rb; do ruby "$f" || exit 1; done`
Expected: all files pass, 0 failures, 0 errors.

- [ ] **Step 9: Commit**

```bash
git add lib/redmine_incident_response/ test/standalone/
git commit -m "refactor: single-pass ontology classification via FieldLookup; fix RFI action inversion, case-sensitive compares, fabricated analyst lane, priority severity mapping"
```

---

### Task 3: Scope ontology validation to IR trackers only (F2)

Currently `IssuePatch` adds `validate_ir_ontology_transition` to every `Issue` in the whole Redmine instance; unrelated projects' issues can be blocked from saving.

**Files:**
- Modify (full rewrite): `lib/redmine_incident_response/issue_patch.rb`
- Create: `test/standalone/issue_patch_test.rb`

**Interfaces:**
- Consumes: `FieldLookup.match?`, `TransitionGuard.evaluate` (Task 2), `Vernacular` constants.
- Produces: `RedmineIncidentResponse::IssuePatch.ir_issue?(issue) -> bool` (module-level, testable without ActiveRecord) and constant `IssuePatch::IR_TRACKER_NAMES`.

- [ ] **Step 1: Write the failing test**

Create `test/standalone/issue_patch_test.rb`:

```ruby
require_relative 'test_helper'

class IssuePatchTest < Minitest::Test
  IP = RedmineIncidentResponse::IssuePatch

  def test_ir_issue_true_for_vernacular_trackers
    ['Incident', 'IOC', 'NAR', 'OBSERVABLE', 'RFI', 'SITREP', 'AAR', 'LOE', 'ME', 'Validated IOC'].each do |name|
      assert IP.ir_issue?(StubIssue.new(tracker: StubTracker.new(name))), "expected #{name} to be an IR tracker"
    end
  end

  def test_ir_issue_false_for_other_trackers
    ['Bug', 'Feature', 'Support', 'Analysis Task', 'Command Update', 'Evidence Item'].each do |name|
      refute IP.ir_issue?(StubIssue.new(tracker: StubTracker.new(name))), "expected #{name} not to be an IR tracker"
    end
  end

  def test_ir_issue_false_without_tracker
    refute IP.ir_issue?(StubIssue.new)
    refute IP.ir_issue?(nil)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby test/standalone/issue_patch_test.rb`
Expected: `NoMethodError: undefined method 'ir_issue?'`.

- [ ] **Step 3: Rewrite `issue_patch.rb`**

Replace the entire contents of `lib/redmine_incident_response/issue_patch.rb` with:

```ruby
module RedmineIncidentResponse
  module IssuePatch
    IR_TRACKER_NAMES = [
      'Incident',
      Vernacular::NAR,
      Vernacular::IOC,
      Vernacular::VALIDATED_IOC,
      Vernacular::OBSERVABLE,
      Vernacular::RFI,
      Vernacular::SITREP,
      Vernacular::AAR,
      Vernacular::LOE,
      Vernacular::ME
    ].freeze

    def self.included(base)
      base.validate :validate_ir_ontology_transition
    end

    def self.ir_issue?(issue)
      tracker_name = issue&.tracker&.name
      return false if tracker_name.blank?

      IR_TRACKER_NAMES.any? { |name| FieldLookup.match?(tracker_name, name) }
    end

    def validate_ir_ontology_transition
      return unless RedmineIncidentResponse::IssuePatch.ir_issue?(self)

      guard = Ontology::TransitionGuard.evaluate(self)
      return if guard.allowed

      guard.messages.each { |msg| errors.add(:base, msg) }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `for f in test/standalone/*_test.rb; do ruby "$f" || exit 1; done`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/redmine_incident_response/issue_patch.rb test/standalone/issue_patch_test.rb
git commit -m "fix: scope IR ontology validation to IR trackers instead of every issue (F2)"
```

---

### Task 4: Harden `quick_action` — real permission + server-side applicability (S1, S2)

Currently any user with generic `edit_issues` can fire any `action_key` at any issue, even ones the classifier never offers it for, and the plugin's own declared permissions are never checked.

**Files:**
- Modify: `app/controllers/incident_response_controller.rb`

**Interfaces:**
- Consumes: `Classifier.classify(issue).quick_actions` (Task 2), permission `:manage_incident_response` declared in `init.rb` (checking it also implicitly requires the `incident_response` project module to be enabled on the issue's project — Redmine's `allowed_to?` returns false for permissions of disabled modules).
- Produces: hardened `POST incident_response/quick_action/:issue_id` behavior relied on by the panel forms (Task 5) and QA (Task 15).

- [ ] **Step 1: Replace the `quick_action` method**

In `app/controllers/incident_response_controller.rb`, replace the existing `quick_action` method with:

```ruby
  def quick_action
    unless User.current.allowed_to?(:edit_issues, @issue.project) &&
           User.current.allowed_to?(:manage_incident_response, @issue.project)
      deny_access
      return
    end

    action_key = params[:action_key].to_s
    offered_keys = RedmineIncidentResponse::Ontology::Classifier
                     .classify(@issue)
                     .quick_actions
                     .filter_map { |action| action[:key] }

    unless offered_keys.include?(action_key)
      flash[:error] = "Quick action '#{action_key}' is not available for this issue."
      redirect_to issue_path(@issue)
      return
    end

    result = RedmineIncidentResponse::QuickActionService.perform(@issue, action_key, User.current)

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:error] = result[:message]
    end

    redirect_to issue_path(@issue)
  end
```

- [ ] **Step 2: Syntax-check the controller**

Run: `ruby -c app/controllers/incident_response_controller.rb`
Expected: `Syntax OK`.

- [ ] **Step 3: [LIVE] Verify on the Redmine host** (defer to Task 15 if unavailable)

As a user with `edit_issues` but **without** `manage_incident_response` (or with the module disabled), POST a quick action and expect 403. As a fully-permitted user, POST a non-offered key (e.g. `promote_nar_to_ioc` on a Bug):

```bash
# from a browser session or curl with a valid session cookie + CSRF token
# Expected: redirect back to the issue with flash error "Quick action 'promote_nar_to_ioc' is not available for this issue."
```

- [ ] **Step 4: Commit**

```bash
git add app/controllers/incident_response_controller.rb
git commit -m "fix(security): require manage_incident_response and server-side action applicability for quick actions (S1, S2)"
```

---

### Task 5: Wire the ontology panel into the issue page hook (F1 — the big one)

The ontology panel (all classification fields + the quick-action buttons + guard messages) is currently unreachable: the hook renders only the basic IR panel, and `_issue_panel.html.erb` (the only referrer of the ontology partial) is itself rendered by nothing.

**Files:**
- Modify: `lib/redmine_incident_response/hooks.rb`
- Delete: `app/views/redmine_incident_response/_issue_panel.html.erb` (dead wrapper, nothing renders it once the hook goes direct)

**Interfaces:**
- Consumes: `IssueHelper.panel_partial -> String`, `IssueHelper.panel_locals(issue) -> Hash` (existing, now efficient via Task 2).
- Produces: both panels rendered under issue details via `view_issues_show_details_bottom`.

- [ ] **Step 1: Update the hook**

In `lib/redmine_incident_response/hooks.rb`, replace the `view_issues_show_details_bottom` method with:

```ruby
    def view_issues_show_details_bottom(context = {})
      issue = context[:issue]
      controller = context[:controller]
      return '' unless issue.present? && controller

      ir_panel = controller.send(
        :render_to_string,
        partial: 'hooks/redmine_incident_response/issue_ir_panel',
        locals: { issue: issue }
      )

      ontology_panel = controller.send(
        :render_to_string,
        partial: RedmineIncidentResponse::IssueHelper.panel_partial,
        locals: RedmineIncidentResponse::IssueHelper.panel_locals(issue)
      )

      ir_panel + ontology_panel
    end
```

(Redmine joins hook results and marks them html_safe in `call_hook`, same as the current single-panel return.)

- [ ] **Step 2: Delete the dead wrapper partial**

```bash
git rm app/views/redmine_incident_response/_issue_panel.html.erb
```

- [ ] **Step 3: Syntax-check**

Run: `ruby -c lib/redmine_incident_response/hooks.rb`
Expected: `Syntax OK`.

- [ ] **Step 4: [LIVE] Verify on the Redmine host** (defer to Task 15 if unavailable)

Deploy (`./deploy.sh`), open any issue: expect BOTH boxes — "Incident Response" table and "Incident Response Ontology Panel" with quick-action buttons on NAR/OBSERVABLE/IOC issues.

- [ ] **Step 5: Commit**

```bash
git add lib/redmine_incident_response/hooks.rb
git commit -m "fix: render ontology panel (quick actions, guard messages) via issue page hook (F1)"
```

---

### Task 6: Dashboard fixes — query out of view, honest incident count (E2, F7)

**Files:**
- Modify: `app/controllers/incident_response_controller.rb` (the `index` action)
- Modify: `app/views/incident_response/index.html.erb`

**Interfaces:**
- Consumes: `Vernacular::IOC`.
- Produces: `@ioc_tracker` (`Tracker|nil`), `@active_incident_count` (Integer, uncapped) for the index view.

- [ ] **Step 1: Replace the `index` action**

In `app/controllers/incident_response_controller.rb`, replace `index` with:

```ruby
  def index
    open_status_ids = IssueStatus.where(is_closed: false).select(:id)
    @ioc_tracker = Tracker.find_by(name: RedmineIncidentResponse::Vernacular::IOC)

    active_incident_scope = Issue.visible
                                 .joins(:tracker)
                                 .where(trackers: { name: 'Incident' })
                                 .where(status_id: open_status_ids)

    @active_incident_count = active_incident_scope.count
    @active_incidents = active_incident_scope
                          .preload(:status, :priority, :assigned_to, :project)
                          .order(updated_on: :desc)
                          .limit(50)

    @open_ioc_count = Issue.visible
                           .joins(:tracker)
                           .where(trackers: { name: RedmineIncidentResponse::Vernacular::IOC })
                           .where(status_id: open_status_ids)
                           .count

    @recent_command_updates = Issue.visible
                                   .joins(:tracker)
                                   .where(trackers: { name: 'Command Update' })
                                   .preload(:status, :project)
                                   .order(updated_on: :desc)
                                   .limit(10)
  end
```

- [ ] **Step 2: Update the view**

In `app/views/incident_response/index.html.erb`:
- Line 11: replace `<%= link_to 'View all IOCs', issues_path(tracker_id: Tracker.find_by(name: 'IOC')&.id) %>` with `<%= link_to 'View all IOCs', issues_path(tracker_id: @ioc_tracker&.id) %>`
- Line 51: replace `<h3>Active Incidents (<%= @active_incidents.size %>)</h3>` with `<h3>Active Incidents (<%= @active_incident_count %>)</h3>`

- [ ] **Step 3: Syntax-check**

Run: `ruby -c app/controllers/incident_response_controller.rb`
Expected: `Syntax OK`.

- [ ] **Step 4: Commit**

```bash
git add app/controllers/incident_response_controller.rb app/views/incident_response/index.html.erb
git commit -m "fix: move tracker lookup out of view, report uncapped active incident count (E2, F7)"
```

---

### Task 7: Dead code removal + fix ValidationChain role names (F8)

`Models::Ioc` is unused and its "normalization" accepts any value (validation that validates nothing) — delete it; the Phase 3.3 IOC data model is custom-fields-based per the storage constraints. `Models::ValidationChain` becomes live in Task 12, but its role names don't match the roles `ir:setup` creates — fix them now.

**Files:**
- Delete: `lib/redmine_incident_response/models/ioc.rb`
- Modify: `init.rb` (remove the ioc require)
- Modify: `lib/redmine_incident_response/models/validation_chain.rb` (ROLES constant)
- Create: `test/standalone/validation_chain_test.rb`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ValidationChain::ROLES == ['Operator', 'Crew Lead', 'Team Lead', 'Commander']` (matches `lib/tasks/ir_setup.rake` role names); `ValidationChain.next_step(role) -> String|nil`; `ValidationChain.escalate(issue, role) -> {issue_id:, current_role:, next_role:, escalatable:}`. Task 12 depends on these.

- [ ] **Step 1: Write the failing test**

Create `test/standalone/validation_chain_test.rb`:

```ruby
require_relative 'test_helper'

class ValidationChainTest < Minitest::Test
  VC = RedmineIncidentResponse::Models::ValidationChain

  def test_roles_match_ir_setup_rake_roles
    assert_equal ['Operator', 'Crew Lead', 'Team Lead', 'Commander'], VC::ROLES
  end

  def test_chain_order
    assert_equal 'Crew Lead', VC.next_step('Operator')
    assert_equal 'Team Lead', VC.next_step('Crew Lead')
    assert_equal 'Commander', VC.next_step('Team Lead')
    assert_nil VC.next_step('Commander')
  end

  def test_unknown_role_returns_nil
    assert_nil VC.next_step('Random Role')
  end

  def test_escalate_payload
    payload = VC.escalate(StubIssue.new(id: 5), 'Operator')
    assert_equal 5, payload[:issue_id]
    assert_equal 'Crew Lead', payload[:next_role]
    assert payload[:escalatable]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `ruby test/standalone/validation_chain_test.rb`
Expected: FAIL — `test_roles_match_ir_setup_rake_roles` (current ROLES start with 'Analyst').

- [ ] **Step 3: Fix ROLES and delete Ioc**

In `lib/redmine_incident_response/models/validation_chain.rb` replace the ROLES line with:

```ruby
      ROLES = ['Operator', 'Crew Lead', 'Team Lead', 'Commander'].freeze
```

Then:

```bash
git rm lib/redmine_incident_response/models/ioc.rb
```

And in `init.rb` delete the line:

```ruby
require_relative 'lib/redmine_incident_response/models/ioc'
```

- [ ] **Step 4: Run all standalone tests**

Run: `for f in test/standalone/*_test.rb; do ruby "$f" || exit 1; done`
Expected: all pass. Also run `grep -rn "Models::Ioc" app lib config init.rb` — expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A lib init.rb test/standalone/validation_chain_test.rb
git commit -m "chore: remove unused Ioc model; align ValidationChain roles with ir:setup roles (F8)"
```

---

### Task 8: Harden `deploy.sh` (S3)

Running it from the wrong CWD currently rsyncs the wrong directory into the plugin dir with `--delete` (destructive), and it pulls whatever branch is checked out.

**Files:**
- Modify (full rewrite): `deploy.sh`

**Interfaces:**
- Consumes/Produces: same CLI (`./deploy.sh` on the Redmine host); `PLUGIN_DIR`/`REDMINE_TMP` now overridable via env.

- [ ] **Step 1: Rewrite `deploy.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Always operate from the repo root, wherever the script is invoked from.
cd "$(dirname "$0")"

PLUGIN_DIR="${PLUGIN_DIR:-/root/redmine-6.1/plugins/redmine_incident_response}"
REDMINE_TMP="${REDMINE_TMP:-/root/redmine-6.1/tmp}"

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${branch}" != "main" ]]; then
  echo "ERROR: deploy.sh deploys 'main' only (currently on '${branch}')." >&2
  exit 1
fi

echo "==> Pulling latest from git..."
git pull --ff-only origin main

echo "==> Syncing plugin files to ${PLUGIN_DIR}..."
rsync -av --delete \
  --exclude='.git' \
  --exclude='deploy.sh' \
  --exclude='Templates/' \
  --exclude='Guidance Documents/' \
  --exclude='docs/superpowers/' \
  --exclude='claude.md' \
  ./ "${PLUGIN_DIR}/"

echo "==> Triggering Passenger restart..."
touch "${REDMINE_TMP}/restart.txt"

echo "==> Done. Plugin deployed."
```

Ops note (outside repo scope, record in README Task 14): Redmine living under `/root/` implies running as root — plan a migration to an unprivileged service account (e.g. `/opt/redmine` owned by `redmine`).

- [ ] **Step 2: Lint**

Run: `bash -n deploy.sh`
Expected: no output (syntax OK). If `shellcheck` is installed, run `shellcheck deploy.sh` — expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add deploy.sh
git commit -m "fix(security): cd to script dir, ff-only pull, main-branch guard in deploy.sh (S3)"
```

---

### Task 9: Seeder credential & portability hardening (S4, S5)

The API key is a plain CLI parameter (lands in PowerShell history / process list) and `$RepoRoot` hardcodes a personal profile path.

**Files:**
- Modify: `/mnt/d/D_Projects/08_Redmine/Initialize-RedmineCyberIRLab.ps1` (lines 1–7, the `param` block — note: this file is OUTSIDE the git repo; no commit, just edit)

**Interfaces:**
- Consumes/Produces: script now reads `REDMINE_API_KEY` env var when `-ApiKey` is omitted; `-RepoRoot` defaults to a `Cyber IR Training Lab` folder next to the script.

- [ ] **Step 1: Replace the param block**

Replace lines 1–7 (`param(...)`) plus add a guard after `$ErrorActionPreference = "Stop"`:

```powershell
param(
    [string]$RepoRoot = (Join-Path (Split-Path -Parent $PSCommandPath) "Cyber IR Training Lab"),
    [string]$RedmineUrl = "http://localhost:3000",
    [string]$ApiKey = $env:REDMINE_API_KEY,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "Provide -ApiKey or set the REDMINE_API_KEY environment variable (preferred: `$env:REDMINE_API_KEY = '<key>' for the session)."
}
```

(Keep everything after the original `$ErrorActionPreference = "Stop"` line unchanged; the original `[Parameter(Mandatory = $true)]` attribute on ApiKey is removed.)

- [ ] **Step 2: Verify**

Run (PowerShell available) `pwsh -NoProfile -Command "& '/mnt/d/D_Projects/08_Redmine/Initialize-RedmineCyberIRLab.ps1' -DryRun"` with no key set.
Expected: throws `Provide -ApiKey or set the REDMINE_API_KEY environment variable...`. If `pwsh` is not installed on this machine, verification defers to the user on Windows; note it and move on.

No commit — file is outside the repo. Note completion in the task tracker instead.

---

## Part B — Project Completion (to Phase 4 complete)

### Task 10: Extend `ir:setup` — full vernacular trackers + all 16 required custom fields

The plugin's ontology needs trackers `NAR/OBSERVABLE/RFI/SITREP/AAR/LOE/ME` and the 16 custom fields listed in README; today neither the rake task nor the seeder creates them (audit F4, plugin side). Trackers cannot be created via the REST API, so the rake task is the right home.

**Files:**
- Modify: `lib/tasks/ir_setup.rake`

**Interfaces:**
- Consumes: Redmine AR models `IssueStatus`, `Tracker`, `Role`, `IssueCustomField` (rake runs inside Redmine).
- Produces: idempotent `bundle exec rake ir:setup` that provisions statuses, all IR trackers, roles, and all custom fields; Tasks 11/12/15 assume these exist.

- [ ] **Step 1: Update the tracker list**

In `lib/tasks/ir_setup.rake`, replace the `tracker_names = [...]` array with:

```ruby
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
```

- [ ] **Step 2: Add custom-field provisioning**

In the same file, insert the following block after the Trackers section and before the Roles section:

```ruby
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
```

- [ ] **Step 3: Syntax-check**

Run: `ruby -c lib/tasks/ir_setup.rake`
Expected: `Syntax OK`.

- [ ] **Step 4: [LIVE] Run on the Redmine host** (defer to Task 15 if unavailable)

```bash
cd /root/redmine-6.1 && bundle exec rake ir:setup RAILS_ENV=production
```

Expected: `[created]` lines for new trackers/fields; run again and expect all `[skip]` (idempotent).

- [ ] **Step 5: Commit**

```bash
git add lib/tasks/ir_setup.rake
git commit -m "feat: provision full vernacular trackers and all 16 IR custom fields in ir:setup"
```

---

### Task 11: Reconcile the lab seeder with the plugin vernacular (F4, seeder side)

**Files:**
- Modify: `/mnt/d/D_Projects/08_Redmine/Initialize-RedmineCyberIRLab.ps1` (`$RequiredTrackers` at lines ~60–74 and `$EnabledModules` at ~76–85; outside git repo — no commit)

**Interfaces:**
- Consumes: trackers created by `ir:setup` (Task 10). The seeder only asserts trackers exist (the REST API cannot create trackers) — run `rake ir:setup` first.
- Produces: a seeded lab whose trackers match the plugin ontology and whose projects have the `incident_response` module enabled (required by the Task 4 permission check).

- [ ] **Step 1: Replace `$RequiredTrackers`**

```powershell
$RequiredTrackers = @(
    "Incident",
    "NAR",
    "IOC",
    "VALIDATED IOC",
    "OBSERVABLE",
    "RFI",
    "SITREP",
    "AAR",
    "LOE",
    "ME",
    "Evidence Item",
    "Command Update",
    "Analysis Task",
    "Investigation Task",
    "Threat Intel Lead",
    "Host Analysis",
    "Network Analysis",
    "Containment Action",
    "Decision Log",
    "Risk / Blocker",
    "Lesson Learned",
    "SOP Improvement"
)
```

(Trackers beyond the `ir:setup` list — Investigation Task, Threat Intel Lead, Host Analysis, Network Analysis, Containment Action, Decision Log, Risk / Blocker, Lesson Learned, SOP Improvement — must be created once in the Redmine admin UI, or added to the `ir:setup` tracker list if the lab standardizes on them; note whichever was done.)

- [ ] **Step 2: Enable the plugin module on seeded projects**

In `$EnabledModules`, add `"incident_response"` as the last entry:

```powershell
$EnabledModules = @(
    "issue_tracking",
    "wiki",
    "documents",
    "files",
    "news",
    "time_tracking",
    "calendar",
    "gantt",
    "incident_response"
)
```

- [ ] **Step 3: [LIVE] Verify** (defer to Task 15 if unavailable)

Run the seeder with `-DryRun` against the lab: expect the tracker assertion to list any missing trackers by name; after `rake ir:setup` (Task 10) only the manually-created ones should be missing.

No commit — outside repo; record completion in the task tracker.

---

### Task 12: Executable "Escalate" quick action + IR status map completion (Phase 4.2 / 4.3)

**Files:**
- Modify: `lib/redmine_incident_response/quick_action_service.rb`
- Modify: `lib/redmine_incident_response/ontology/classifier.rb` (one line: escalate action key)
- Modify: `lib/redmine_incident_response/models/ir_status_map.rb`
- Create: `test/standalone/quick_action_service_test.rb`
- Create: `test/standalone/ir_status_map_test.rb`

**Interfaces:**
- Consumes: `ValidationChain` (Task 7 role names), `FieldLookup`, classifier from Task 2.
- Produces: `QuickActionService.perform(issue, 'escalate', user)` sets custom field `Lifecycle State` to `'Escalated'` and reports the next role; classifier emits `{ label: 'Escalate to Crew Lead', key: 'escalate' }` when eligible. `IrStatusMap::DEFAULT_MAP` covers all six `ir:setup` statuses.

- [ ] **Step 1: Write the failing tests**

Create `test/standalone/quick_action_service_test.rb`:

```ruby
require_relative 'test_helper'

class QuickActionServiceTest < Minitest::Test
  QAS = RedmineIncidentResponse::QuickActionService
  StubRole = Struct.new(:name)

  class StubUser
    def initialize(role_names)
      @role_names = role_names
    end

    def roles_for_project(_project)
      @role_names.map { |name| StubRole.new(name) }
    end
  end

  def validated_ioc_issue
    StubIssue.new(
      tracker: StubTracker.new('IOC'),
      fields: { 'Lifecycle State' => 'VALIDATED IOC' }
    )
  end

  def test_escalate_sets_lifecycle_and_reports_next_role
    issue = validated_ioc_issue
    result = QAS.perform(issue, 'escalate', StubUser.new(['Operator']))
    assert result[:success], result[:message]
    assert_match(/Crew Lead/, result[:message])
    assert_equal 'Escalated', RedmineIncidentResponse::FieldLookup.custom_field_value(issue, 'Lifecycle State')
  end

  def test_escalate_picks_highest_matching_role
    result = QAS.perform(validated_ioc_issue, 'escalate', StubUser.new(['Operator', 'Team Lead']))
    assert result[:success], result[:message]
    assert_match(/Commander/, result[:message])
  end

  def test_escalate_fails_at_top_of_chain
    result = QAS.perform(validated_ioc_issue, 'escalate', StubUser.new(['Commander']))
    refute result[:success]
  end

  def test_unknown_action_fails
    result = QAS.perform(validated_ioc_issue, 'bogus_action', StubUser.new(['Operator']))
    refute result[:success]
    assert_match(/Unknown quick action/, result[:message])
  end

  def test_submit_for_validation_sets_pending
    issue = StubIssue.new(tracker: StubTracker.new('IOC'), fields: { 'Lifecycle State' => 'IOC' })
    result = QAS.perform(issue, 'submit_for_validation', StubUser.new(['Operator']))
    assert result[:success], result[:message]
    assert_equal 'Pending Validation', RedmineIncidentResponse::FieldLookup.custom_field_value(issue, 'Lifecycle State')
  end
end
```

Create `test/standalone/ir_status_map_test.rb`:

```ruby
require_relative 'test_helper'

class IrStatusMapTest < Minitest::Test
  M = RedmineIncidentResponse::Models::IrStatusMap

  def test_maps_all_ir_setup_statuses
    assert_equal 'Triage', M.lifecycle_for('New')
    assert_equal 'Analysis', M.lifecycle_for('In Progress')
    assert_equal 'Pending Validation', M.lifecycle_for('Pending Validation')
    assert_equal 'Validated IOC', M.lifecycle_for('Validated IOC')
    assert_equal 'Escalated', M.lifecycle_for('Escalated')
    assert_equal 'Closed', M.lifecycle_for('Closed')
  end

  def test_unknown_status_passes_through
    assert_equal 'Feedback', M.lifecycle_for('Feedback')
  end

  def test_nil_returns_nil
    assert_nil M.lifecycle_for(nil)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `ruby test/standalone/quick_action_service_test.rb; ruby test/standalone/ir_status_map_test.rb`
Expected: escalate tests fail (`Unknown quick action: escalate`); status-map test fails on `Pending Validation`/`Validated IOC`/`Escalated`.

- [ ] **Step 3: Implement the escalate action**

Replace the entire contents of `lib/redmine_incident_response/quick_action_service.rb` with:

```ruby
module RedmineIncidentResponse
  module QuickActionService
    module_function

    def perform(issue, action_key, user)
      issue.init_journal(user) if issue.respond_to?(:init_journal)

      case action_key
      when 'promote_nar_to_ioc', 'convert_observable_to_ioc'
        change_tracker(issue, Vernacular::IOC)
      when 'convert_to_rfi'
        change_tracker(issue, Vernacular::RFI)
      when 'submit_for_validation'
        set_custom_field(issue, 'Lifecycle State', 'Pending Validation')
      when 'escalate'
        escalate(issue, user)
      else
        { success: false, message: "Unknown quick action: #{action_key}" }
      end
    end

    def change_tracker(issue, tracker_name)
      tracker = Tracker.find_by(name: tracker_name)
      return { success: false, message: "Tracker '#{tracker_name}' is not configured in Redmine." } unless tracker

      issue.tracker = tracker
      if issue.save
        { success: true, message: "Tracker changed to #{tracker_name}." }
      else
        { success: false, message: issue.errors.full_messages.join('; ') }
      end
    end
    private_class_method :change_tracker

    def set_custom_field(issue, field_name, value)
      cfv = issue.custom_field_values.find { |v| v.custom_field&.name == field_name }
      return { success: false, message: "Custom field '#{field_name}' is not configured on this issue." } unless cfv

      cfv.value = value
      if issue.save
        { success: true, message: "#{field_name} set to #{value}." }
      else
        { success: false, message: issue.errors.full_messages.join('; ') }
      end
    end
    private_class_method :set_custom_field

    def escalate(issue, user)
      role_name = escalation_role_for(issue, user)
      chain = Models::ValidationChain.escalate(issue, role_name)
      unless chain[:escalatable]
        return { success: false, message: "No escalation step above #{role_name}." }
      end

      result = set_custom_field(issue, 'Lifecycle State', 'Escalated')
      return result unless result[:success]

      { success: true, message: "Escalated from #{role_name} toward #{chain[:next_role]}." }
    end
    private_class_method :escalate

    def escalation_role_for(issue, user)
      return Models::ValidationChain::ROLES.first unless user.respond_to?(:roles_for_project)

      names = user.roles_for_project(issue.project).map(&:name)
      Models::ValidationChain::ROLES.reverse.find { |role| names.include?(role) } ||
        Models::ValidationChain::ROLES.first
    end
    private_class_method :escalation_role_for
  end
end
```

- [ ] **Step 4: Turn on the escalate button**

In `lib/redmine_incident_response/ontology/classifier.rb`, in `quick_actions_for`, change:

```ruby
          actions << { label: 'Escalate to Crew Lead', key: nil }
```

to:

```ruby
          actions << { label: 'Escalate', key: 'escalate' }
```

- [ ] **Step 5: Complete the status map**

In `lib/redmine_incident_response/models/ir_status_map.rb`, replace `DEFAULT_MAP` with:

```ruby
      DEFAULT_MAP = {
        'New' => 'Triage',
        'In Progress' => 'Analysis',
        'Pending Validation' => 'Pending Validation',
        'Validated IOC' => 'Validated IOC',
        'Escalated' => 'Escalated',
        'Resolved' => 'Recovery',
        'Closed' => 'Closed'
      }.freeze
```

- [ ] **Step 6: Run all standalone tests**

Run: `for f in test/standalone/*_test.rb; do ruby "$f" || exit 1; done`
Expected: all pass (the Task 2 classifier test asserting the escalate label doesn't exist — none does — so no conflicts; if any test asserted the old 'Escalate to Crew Lead' label, update it to 'Escalate').

- [ ] **Step 7: Commit**

```bash
git add lib/redmine_incident_response/ test/standalone/
git commit -m "feat: executable escalate quick action via ValidationChain; complete IR status map (Phase 4.2/4.3)"
```

---

### Task 13: Dashboard honors `view_incident_response` (finish S1)

Make the declared read permission real: admins keep access; non-admins need `view_incident_response` granted in at least one project (Redmine global permission check).

**Files:**
- Modify: `app/controllers/incident_response_controller.rb`

**Interfaces:**
- Consumes: permission `:view_incident_response` from `init.rb`.
- Produces: `GET /incident_response` reachable by admins and permitted users; 403 otherwise. Menu stays in `admin_menu` (Commander dashboards for non-admins are Phase 6 scope).

- [ ] **Step 1: Replace the before_action block**

At the top of `app/controllers/incident_response_controller.rb`, replace:

```ruby
  before_action :require_login
  before_action :require_admin, only: [:index]
  before_action :find_ir_issue, only: [:quick_action]
```

with:

```ruby
  before_action :require_login
  before_action :authorize_dashboard, only: [:index]
  before_action :find_ir_issue, only: [:quick_action]
```

and add to the `private` section:

```ruby
  def authorize_dashboard
    return if User.current.admin?
    return if User.current.allowed_to?(:view_incident_response, nil, global: true)

    deny_access
  end
```

- [ ] **Step 2: Syntax-check**

Run: `ruby -c app/controllers/incident_response_controller.rb`
Expected: `Syntax OK`.

- [ ] **Step 3: Commit**

```bash
git add app/controllers/incident_response_controller.rb
git commit -m "feat: allow view_incident_response holders onto the IR dashboard (S1)"
```

---

### Task 14: Documentation truth pass

**Files:**
- Modify: `README.md`
- Modify: `claude.md`
- Modify: `docs/vernacular_standard.md` (only if it contradicts the RFI-action change; check first)

**Interfaces:** none — docs only.

- [ ] **Step 1: Update README**

In `README.md`:
1. In the "Issue page panel" section, after the existing hook sentence, add: `Quick actions (Promote NAR → IOC, Convert OBSERVABLE → IOC/RFI, Convert NAR → RFI, Submit IOC for Validation, Escalate) render as buttons in the panel and POST to the plugin's quick_action endpoint. They require the project's Incident Response module to be enabled and the manage_incident_response permission.`
2. Replace the entire "Verification Status" section (from `## Verification Status` to the end of file) with:

```markdown
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
```

3. Delete the temporary "Current Plan (2026-07-07)" known-issue sentence about the panel not rendering (added at planning time) — it stops being true once Task 5 lands; keep the link to the plan file.

- [ ] **Step 2: Update `claude.md`**

Replace the `## Current Phase` section body with:

```markdown
Phase 4 per plugin_roadmap.txt — workflow engine (escalation chain, status map) complete;
Phases 5–7 (data import, command dashboard, intel layer) not started.
Active plan: docs/superpowers/plans/2026-07-07-audit-remediation-and-completion.md
```

- [ ] **Step 3: Check `docs/vernacular_standard.md`**

Run: `grep -n "RFI" docs/vernacular_standard.md`. If it documents the old "Convert to RFI offered on RFI issues" behavior, correct it to "offered on NAR and OBSERVABLE issues". If it doesn't mention quick actions, leave it.

- [ ] **Step 4: Commit**

```bash
git add README.md claude.md docs/
git commit -m "docs: setup/testing instructions, phase status, quick-action documentation"
```

---

### Task 15: [LIVE] Full verification pass on Redmine 6.1.2 — release gate

Everything below runs against the live Redmine host after `./deploy.sh` (or manual rsync) and `bundle exec rake ir:setup`. This is the acceptance gate for the whole plan; also execute any steps deferred from earlier tasks.

**Files:** none (verification only). Record results in `docs/manual_validation.md` (append a dated section).

- [ ] **Step 1: Deploy and provision**

```bash
./deploy.sh
cd /root/redmine-6.1 && bundle exec rake ir:setup RAILS_ENV=production
```

Expected: deploy completes; rake idempotent output; Redmine restarts cleanly (check `log/production.log` for plugin load errors — expect none).

- [ ] **Step 2: Panels render (Task 5)** — open any IR-tracker issue: both "Incident Response" and "Incident Response Ontology Panel" boxes appear; a non-IR issue (Bug) still shows both panels with 'Not set' values but must save without IR validation interference.

- [ ] **Step 3: Quick actions work end-to-end (Tasks 2, 4, 12)** — on a NAR issue: buttons "Promote NAR → IOC" and "Convert NAR → RFI" appear; clicking Promote changes tracker to IOC with a success flash. On the (now) IOC issue: "Submit IOC for Validation" sets Lifecycle State = Pending Validation. Set Validation Disposition=VERIFIED, Rationale, Reviewer, Lifecycle State=VALIDATED IOC: "Escalate" appears; clicking sets Lifecycle State=Escalated and the flash names the next role.

- [ ] **Step 4: Guard blocks bad transitions (Task 3)** — on a NAR issue set Lifecycle State=VALIDATED IOC and save: expect validation error "NAR or OBSERVABLE cannot be promoted directly to VALIDATED IOC." On a Bug issue set any coincidental fields and save: expect NO IR validation errors.

- [ ] **Step 5: Permissions (Tasks 4, 13)** — user with edit_issues but module disabled → quick action POST returns 403. Module enabled + manage_incident_response → succeeds. Non-offered action_key POST → flash error, no change. Non-admin without view_incident_response → `/incident_response` 403; with it → dashboard renders with correct uncapped incident count.

- [ ] **Step 6: Record results** — append a "2026-XX-XX live validation" section to `docs/manual_validation.md` with pass/fail per step above.

- [ ] **Step 7: Merge**

```bash
git add docs/manual_validation.md
git commit -m "docs: record live validation results for audit remediation release"
git checkout main && git merge --no-ff fix/audit-remediation -m "merge: audit remediation + phase 4 completion"
```

---

## Out of Scope — future plans (do NOT implement here)

Per roadmap `plugin_roadmap.txt`, each of these is a separate follow-up plan with its own spec:

- **Phase 5 — Data Import System:** CSV/XLSX user + org-structure ingestion, role mapping (`Templates/01_users_import.csv` is the seed artifact). Separate plan; touches none of the files above except possibly a new rake task.
- **Phase 6 — Command Dashboard:** LOE overview, IOC validation queue, workload distribution; replaces the admin-menu dashboard with a project-level Commander view.
- **Phase 7 — Intelligence/APT Layer:** IOC→APT correlation, threat-actor tagging, cross-incident clustering (the `Cross-Incident Correlation ID` / `Threat Actor Tags` custom fields from Task 10 are its ready inputs).

---

## Appendix — 2026-07-07 audit finding index

| ID | Severity | Finding | Fixed in |
|----|----------|---------|----------|
| S1 | Medium | Declared plugin permissions never enforced; quick_action only checks edit_issues | Tasks 4, 13 |
| S2 | Low-Med | quick_action doesn't validate action applicability server-side | Task 4 |
| S3 | Low | deploy.sh: CWD-dependent destructive rsync, root-owned Redmine, unguarded pull | Task 8 |
| S4 | Low | Seeder API key on command line | Task 9 |
| S5 | Info | Placeholder password / personal paths in docs & seeder | Tasks 9, 14 |
| F1 | High | Ontology panel + quick-action UI unreachable (no hook renders it) | Task 5 |
| F2 | Medium | Ontology validation runs on every issue instance-wide | Task 3 |
| F3 | Medium | "Convert to RFI" offered only on issues that already are RFIs | Task 2 |
| F4 | Medium | Tracker names hard-coded; seeder/rake/vernacular tracker sets disjoint | Tasks 10, 11 |
| F5 | Low | Raw `!=` compare for submit-for-validation visibility | Task 2 |
| F6 | Low | Fabricated analyst lane from issue.id modulo | Task 2 |
| F7 | Low | Dashboard incident count capped at 50 | Task 6 |
| F8 | Low | Dead code: Models::Ioc (no-op validation), ValidationChain unused/wrong roles | Tasks 7, 12 |
| F9 | High | No tests at all | Tasks 1–3, 7, 12 |
| E1 | Medium | Classifier runs 3–4× per render; 17 linear field scans each | Task 2 |
| E2 | Low | DB query in view | Task 6 |
| E4 | Low | custom_field_value ×3, normalize_compare_value ×2 duplication | Tasks 1, 2 |
| — | Low | Context severity ignored Urgent/Immediate/Normal priorities (found during planning) | Task 2 |
