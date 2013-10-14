module ActiveRecord
  module Serialization
    extend ActiveSupport::Concern

    module ClassMethods
      def initialize_attributes(attributes, options = {}) #:nodoc:
        serialized = (options.delete(:serialized) { true }) ? :serialized : :unserialized
        #super(attributes, options)

        serialized_attributes.each do |key, coder|
          if attributes.key?(key)
            attributes[key] = Attribute.new(coder, attributes[key], serialized)
          end
        end

        attributes
      end
    end

  end
end

module ActiveRecord
  module Associations
    extend ActiveSupport::Concern

    attr_reader :association_cache

    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        reflection  = self.class.reflect_on_association(name)
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    private
      # Returns the specified association instance if it responds to :loaded?, nil otherwise.
      def association_instance_get(name)
        @association_cache[name]
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        @association_cache[name] = association
      end
    end
end

module ActiveRecord
  module Reflection
    class AssociationReflection
      extend ActiveSupport::Concern

      
      def association_class
        case macro
        when :belongs_to
          if options[:polymorphic]
            Associations::BelongsToPolymorphicAssociation
          else
            Associations::BelongsToAssociation
          end
        when :has_and_belongs_to_many
          Associations::HasAndBelongsToManyAssociation
        when :has_many
          if options[:through]
            Associations::HasManyThroughAssociation
          else
            Associations::HasManyAssociation
          end
        when :has_one
          if options[:through]
            Associations::HasOneThroughAssociation
          else
            Associations::HasOneAssociation
          end
        end
      end
    end
  end
end