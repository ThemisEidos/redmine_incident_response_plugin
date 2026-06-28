module RedmineIncidentResponse
  module Vernacular
    NAR = 'NAR'.freeze
    IOC = 'IOC'.freeze
    VALIDATED_IOC = 'VALIDATED IOC'.freeze
    OBSERVABLE = 'OBSERVABLE'.freeze
    LOE = 'LOE'.freeze
    ME = 'ME'.freeze
    EVIDENCE_REFERENCE = 'Evidence Reference'.freeze
    SITREP = 'SITREP'.freeze
    RFI = 'RFI'.freeze
    AAR = 'AAR'.freeze

    CANONICAL_TERMS = {
      nar: NAR,
      ioc: IOC,
      validated_ioc: VALIDATED_IOC,
      observable: OBSERVABLE,
      loe: LOE,
      me: ME,
      evidence_reference: EVIDENCE_REFERENCE,
      sitrep: SITREP,
      rfi: RFI,
      aar: AAR
    }.freeze

    DEPRECATED_SYNONYMS = {
      'IOC Alert' => IOC,
      'Detection Event' => IOC,
      'Finding' => OBSERVABLE,
      'Case' => 'Incident',
      'Validation Report' => 'IOC Validation',
      'Confirmed IOC' => VALIDATED_IOC
    }.freeze

    TRACKER_LABELS = {
      incident: 'Incident',
      nar: NAR,
      ioc: IOC,
      validated_ioc: VALIDATED_IOC,
      evidence_reference: EVIDENCE_REFERENCE,
      sitrep: SITREP,
      rfi: RFI,
      aar: AAR
    }.freeze
  end
end
