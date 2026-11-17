require 'date'
require 'time'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to setting the
    # document's core properties (title, subject, creator and so on), which
    # docProps/core.xml holds.
    #
    module CoreProperties
      TEXT_PROPERTIES = %i(title subject creator keywords description last_modified_by)
      DATE_PROPERTIES = %i(created modified)

      # Returns the date in W3CDTF (ISO 8601 in UTC), or nil if the value
      # is not a date.
      #
      def self.w3cdtf(value)
        time = case value
               when DateTime, Time then value.to_time
               when Date           then Time.utc value.year, value.month, value.day
               else DateTime.parse(value.to_s).to_time
               end
        time.getutc.iso8601
      rescue Date::Error
        nil
      end

      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          # Each property is set by passing a value, e.g. `title 'Report'`,
          # and returned when called without one.
          #
          (TEXT_PROPERTIES + DATE_PROPERTIES).each do |property|
            define_method property do |*args|
              return core_properties[property] if args.empty?

              send "#{ property }=", *args
            end

            define_method "#{ property }=" do |value|
              if DATE_PROPERTIES.include? property and not value.nil? and CoreProperties.w3cdtf(value).nil?
                raise Caracal::Errors::InvalidModelError, "#{ property } must be a Date, Time, DateTime or date string."
              end

              core_properties[property] = value
            end
          end

          #============== GETTERS =============================

          def core_properties
            @core_properties ||= {}
          end

        end
      end
    end

  end
end
