module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed for functions that
      # do not store or manipulate data.
      class BaseModel
        attr_reader :errors

        # initialization
        def initialize(options={}, &block)
          @errors = []

          options.each do |(key, value)|
            # send(key, value) if option_keys.include?(key) # safer, but need to define complete border model accessors first.
            if respond_to? key
              send key, value
            else
              raise "trying to set #{key.inspect} which is not known to #{self.inspect}"
            end
          end

          if block_given?
            (block.arity < 1) ? instance_exec(&block) : block[self]
          end
        end

        #=============== VALIDATION ===========================

        def valid?
          true
        end

        def get_model(name)
          self.instance_variable_get "@#{self.class.attr_prefix}_#{name}"
        end

        private

        def option_keys
          []
        end

        def validate_all(attr, allow_nil: false)
          array = self.send attr
          if array.nil? and allow_nil
            true
          elsif array.all? :valid?
            true
          else
            @errors << {message: array.reject{|a| a.errors.nil? or a.errors.empty? }.map{|a| a.errors }, model: self, attribute: attr}
            false
          end
        end

        def validate_size(attr, at_least: 0, allow_nil: false)
          value = self.send "#{self.class.attr_prefix}_#{attr}"
          if value.nil? and allow_nil
            true
          elsif not value.nil? and value > at_least
            true
          else
            @errors << {message: "#{attr} must be greater than #{at_least}", model: self, attribute: attr, value: value}
            false
          end
        end

        def validate_presence(attr, allow_empty: false)
          value = self.send "#{self.class.attr_prefix}_#{attr}"

          value_empty = value.respond_to?(:empty?) ? value.empty? : false

          if not value.nil? and ((value_empty and allow_empty) or not value_empty)
            true
          else
            @errors << {message: "#{attr} must not be empty", model: self, attribute: attr, value: value}
            false
          end
        end

        def validate_inclusion(attr, within: [], allow_nil: true)
          value = self.send "#{self.class.attr_prefix}_#{attr}"
          if (allow_nil and value.nil?) or within.include? value
            true
          else
            @errors << {message: "#{value.inspect} is not in #{within.inspect}", model: self, attribute: attr, value: value}
            false
          end
        end

        def validate(msg, &block)
          if yield
            true
          else
            @errors << {message: msg, model: self}
            false
          end
        end

        def self.use_prefix(str)
          define_singleton_method :attr_prefix do
            str.to_s
          end
        end

        def self.define_reader_and_default(name, default: nil)
          self.const_set :"DEFAULT_#{attr_prefix.upcase}_#{name.to_s.upcase}", default
          attr_reader "#{attr_prefix}_#{name}"
        end

        def self.has_integer_attribute(name, default: nil)
          define_reader_and_default name, default: default

          prefix = self.attr_prefix
          define_method name do |value|
            v = value.nil? ? nil : value.to_i
            instance_variable_set "@#{prefix}_#{name}", v
          end
        end

        def self.has_symbol_attribute(name, default: nil, downcase: false)
          define_reader_and_default name, default: default
          prefix = self.attr_prefix

          define_method name do |value|
            if value.nil?
              instance_variable_set "@#{prefix}_#{name}", nil
            else
              v = value.to_s
              v = v.downcase if downcase
              instance_variable_set "@#{prefix}_#{name}", v.to_sym
            end
          end
        end

        def self.has_string_attribute(name, default: nil)
          define_reader_and_default name, default: default

          prefix = self.attr_prefix
          define_method name do |value|
            v = value.nil? ? nil : value.to_s
            instance_variable_set "@#{prefix}_#{name}", v
          end
        end

        def self.has_boolean_attribute(name, default: nil)
          define_reader_and_default name, default: default

          prefix = self.attr_prefix
          define_method name do |value|
            case value
            when nil, 'nil', 'none'
              v = nil
            when 'false', false, 0, '0'
              v = false
            else
              v = true
            end

            instance_variable_set "@#{prefix}_#{name}", v
          end
        end

        def self.has_model_attribute(name, model: nil, default: nil)
          define_reader_and_default name, default: default

          prefix = self.attr_prefix
          define_method name do |options={}, &block|
            case options
            when model
              if block_given?
                options.instance_eval &block
              end
              v = options
            when nil
              v = nil
            else
              v = model.new(options, &block)
            end
            if v.valid?
              instance_variable_set "@#{prefix}_#{name}", v
            else
              raise Caracal::Errors::InvalidModelError, v.errors.inspect
            end

          end
        end
      end

    end
  end
end
