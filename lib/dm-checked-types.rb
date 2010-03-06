require 'dm-checked-types/checked_integer'
require 'dm-checked-types/migrations'

module DataMapper
  module Migrations
    constants.each do |const_name|
      if CheckedTypes.const_defined?(const_name)
        mod = const_get(const_name)
        mod.send(:include, CheckedTypes.const_get(const_name))
      end
    end
  end
end
