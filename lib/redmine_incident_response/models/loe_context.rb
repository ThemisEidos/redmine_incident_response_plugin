module RedmineIncidentResponse
  module Models
    class LoeContext
      DEFAULT_FIELD_NAME = 'LOE'.freeze
      PREFIX_PATTERN = /\A\[(?<loe>[^\]]+)\]\s*/.freeze

      attr_reader :label, :source

      def initialize(label:, source:)
        @label = label
        @source = source
      end

      def self.build(issue)
        return new(label: nil, source: :none) unless issue

        field_label = custom_field_loe(issue)
        return new(label: field_label, source: :custom_field) if field_label.present?

        prefix_label = subject_prefix_loe(issue)
        return new(label: prefix_label, source: :subject_prefix) if prefix_label.present?

        new(label: nil, source: :none)
      end

      def grouped?
        label.present?
      end

      def self.custom_field_loe(issue)
        return nil unless issue.respond_to?(:custom_field_values)

        field_value = issue.custom_field_values.find do |value|
          value.custom_field&.name == DEFAULT_FIELD_NAME
        end

        field_value&.value.presence
      end
      private_class_method :custom_field_loe

      def self.subject_prefix_loe(issue)
        subject = issue.respond_to?(:subject) ? issue.subject.to_s : ''
        match = subject.match(PREFIX_PATTERN)
        match&.[](:loe).to_s.strip.presence
      end
      private_class_method :subject_prefix_loe
    end
  end
end
