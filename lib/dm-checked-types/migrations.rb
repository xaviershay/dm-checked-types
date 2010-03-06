module CheckedTypes
  module DataObjectsAdapter
    def create_custom_type_statements(repository_name, model)
      model.properties.select {|x| x.type.ancestors.include?(CheckedInteger) }.each do |property|
        table_name      = model.storage_name(repository_name)
        property.type.range.each do |key, value|
          comparator = {
            :gt  => '>',
            :gte => '>=',
            :lt  => '<',
            :lte => '<='
          }[key] || raise(ArgumentError.new("Unsupported comparator: #{key}"))

          sql = <<-EOS.compress_lines
            ALTER TABLE #{quote_name(table_name)}
            ADD CONSTRAINT #{quote_name(check_constraint_name(table_name, property.name, key))}
            CHECK (#{quote_name(property.field)} #{comparator} #{value})
          EOS
          execute(sql)
        end
      end
    end

    def destroy_custom_type_statements(repository_name, model)
      model.properties.select {|x| x.type.ancestors.include?(CheckedInteger) }.each do |property|
        table_name = model.storage_name(repository_name)

        property.type.range.each do |key, value|
          constraint_name = check_constraint_name(table_name, property.name, key)

          next unless constraint_exists?(model.storage_name, constraint_name)

          sql = <<-EOS.compress_lines
            ALTER TABLE #{quote_name(model.storage_name(repository_name))}
            DROP CONSTRAINT #{quote_name(constraint_name)}
          EOS
          execute(sql)
        end
      end.compact
    end

    private

    def check_constraint_name(table_name, relationship_name, comparator_name)
      "#{table_name}_#{relationship_name}_#{comparator_name}"
    end

    def quote_constraint_name(foreign_key)
      quote_table_name(foreign_key)
    end
  end

  module SingletonMethods
    def self.included(base)
      # TODO: figure out how to make this work without AMC
      base.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        alias_method :auto_migrate_down_without_custom_types!, :auto_migrate_down!
        alias_method :auto_migrate_down!, :auto_migrate_down_with_custom_types!

        alias_method :auto_migrate_up_without_custom_types!, :auto_migrate_up!
        alias_method :auto_migrate_up!, :auto_migrate_up_with_custom_types!
      RUBY
    end

    def auto_migrate_down_with_custom_types!(repository_name = nil)
      repository_execute(:auto_migrate_down_with_custom_types!, repository_name)
      auto_migrate_down_without_custom_types!(repository_name)
    end

    def auto_migrate_up_with_custom_types!(repository_name = nil)
      auto_migrate_up_without_custom_types!(repository_name)
      repository_execute(:auto_migrate_up_with_custom_types!, repository_name)
    end
  end

  module Model
    def auto_migrate_down_with_custom_types!(repository_name = self.repository_name)
      return unless storage_exists?(repository_name)
      return if self.respond_to?(:is_remixable?) && self.is_remixable?

      adapter = DataMapper.repository(repository_name).adapter
      adapter.destroy_custom_type_statements(repository_name, self)
    end

    def auto_migrate_up_with_custom_types!(repository_name = self.repository_name)
      return if self.respond_to?(:is_remixable?) && self.is_remixable?

      adapter = DataMapper.repository(repository_name).adapter
      adapter.create_custom_type_statements(repository_name, self)
    end
  end
end
