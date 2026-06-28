require 'json'

module RedmineIncidentResponse
  module Models
    class Ioc
      TYPES = %w[host network file domain ip].freeze
      CONFIDENCE_LEVELS = %w[low medium high].freeze

      attr_reader :type, :value, :confidence, :severity, :associated_issue_id, :notes

      def initialize(type:, value:, confidence:, severity:, associated_issue_id:, notes:)
        @type = normalize_type(type)
        @value = value.to_s
        @confidence = normalize_confidence(confidence)
        @severity = severity.to_s
        @associated_issue_id = associated_issue_id
        @notes = notes.to_s
      end

      def to_h
        {
          type: type,
          value: value,
          confidence: confidence,
          severity: severity,
          associated_issue_id: associated_issue_id,
          notes: notes
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def self.from_h(data)
        new(
          type: data[:type] || data['type'],
          value: data[:value] || data['value'],
          confidence: data[:confidence] || data['confidence'],
          severity: data[:severity] || data['severity'],
          associated_issue_id: data[:associated_issue_id] || data['associated_issue_id'],
          notes: data[:notes] || data['notes']
        )
      end

      private

      def normalize_type(value)
        normalized = value.to_s.strip.downcase
        return normalized if TYPES.include?(normalized)

        normalized
      end

      def normalize_confidence(value)
        normalized = value.to_s.strip.downcase
        return normalized if CONFIDENCE_LEVELS.include?(normalized)

        normalized
      end
    end
  end
end
