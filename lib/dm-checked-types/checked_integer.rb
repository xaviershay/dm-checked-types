class CheckedInteger < DataMapper::Type
  primitive Integer

  def self.inherited(target)
    target.instance_variable_set('@primitive', self.primitive)
  end

  def self.range
    @range || {}
  end

  def self.range=(value)
    @range = value
  end

  def self.new(range)
    type = generated_types[range] || Class.new(CheckedInteger)
    type.range = range
    generated_types[range] = type
    type
  end

  def self.generated_types
    @generated_types ||= {}
  end

  def self.[](range = {})
    new(range)
  end

  def self.bind(property)
    if defined?(::DataMapper::Validate)
      model = property.model

      unless model.skip_auto_validation_for?(property)
        if property.type.ancestors.include?(CheckedInteger)
          range = self.range
          model.class_eval do
            lower_bound = range[:gte]
            lower_bound ||= range[:gt] + 1 if range[:gt]
            lower_bound ||= -n

            upper_bound = range[:lt] - 1 if range[:lt]
            upper_bound ||= range[:lte]
            upper_bound ||= n

            validates_within property.name, :set => (lower_bound..upper_bound)
          end
        end
      end
    end
  end
end
