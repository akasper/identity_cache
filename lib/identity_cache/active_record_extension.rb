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
  # = Active Record Reflection
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    class AssociationReflection < MacroReflection
      def foreign_key
        @foreign_key ||= options[:foreign_key] || derive_foreign_key
      end

      def derive_foreign_key
        if belongs_to?
          "#{name}_id"
        elsif options[:as]
          "#{options[:as]}_id"
        else
          active_record.name.foreign_key
        end
      end
    end
  end
end

module ActiveRecord
  module Associations
    extend ActiveSupport::Concern

    attr_reader :association_cache

    private
      # Set the specified association instance.
      def delete_from_cache(name)
        instance_variable_set "@#{name}", nil
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