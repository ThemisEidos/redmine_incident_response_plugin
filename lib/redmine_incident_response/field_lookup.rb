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
