require 'date'
require 'time'
require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # custom properties
      class CustomPropertyModel < BaseModel
        use_prefix :custom_property

        has_string_attribute :name
        has_string_attribute :type

        # the value keeps its class, so dates and numbers survive until rendering
        attr_reader :custom_property_value

        def value(value)
          @custom_property_value = value
        end

        #=============== GETTERS ==============================

        # ISO 8601 in UTC, as required by vt:filetime
        def custom_property_date
          time = case v = custom_property_value
                 when DateTime, Time then v.to_time
                 when Date           then Time.utc v.year, v.month, v.day
                 else DateTime.parse(v.to_s).to_time
                 end
          time.getutc.iso8601
        rescue Date::Error
          nil
        end

        def custom_property_number
          v = custom_property_value
          return v if v.is_a? Numeric

          Integer(v.to_s, 10, exception: false) || Float(v.to_s, exception: false)
        end

        #=============== VALIDATION ===========================

        def valid?
          option_keys.all? {|m| validate_presence m } and valid_value?
        end

        private

        def valid_value?
          case custom_property_type.downcase
          when 'date'   then validate('value must be a date')   { custom_property_date }
          when 'number' then validate('value must be a number') { custom_property_number }
          else true
          end
        end

        def option_keys
          [:name, :value, :type]
        end

      end
    end
  end
end
