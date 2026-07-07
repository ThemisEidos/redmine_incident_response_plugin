module RedmineIncidentResponse
  module Models
    class ValidationChain
      ROLES = ['Operator', 'Crew Lead', 'Team Lead', 'Commander'].freeze

      def self.next_step(role)
        index = role_index(role)
        return nil if index.nil?

        ROLES[index + 1]
      end

      def self.escalate(issue, role)
        {
          issue_id: issue&.id,
          current_role: normalize_role(role),
          next_role: next_step(role),
          escalatable: !next_step(role).nil?
        }
      end

      def self.role_index(role)
        ROLES.index(normalize_role(role))
      end
      private_class_method :role_index

      def self.normalize_role(role)
        role.to_s.strip
      end
      private_class_method :normalize_role
    end
  end
end
