module Caracal
  module View
    def docx
      @docx ||= Caracal::Document.new
    end

    def save_as(name)
      file_name name
      save
    end

    def render
      buffer = docx.render
      buffer.rewind
      buffer.sysread
    end

    def update(&block)
      instance_eval &block
    end

    def method_missing(method_name, *arguments, &block)
      return super unless docx.respond_to? method_name

      docx.send method_name, *arguments, &block
    end

    def respond_to_missing?(method_name, _include_private = false)
      docx.respond_to? method_name
    end
  end
end
