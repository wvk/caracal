require 'tempfile'
require 'caracal/core/models/base_model'
require 'caracal/errors'

module Caracal
  module Core
    module Models

      # This class handles block options passed to the img method.
      class IFrameModel < BaseModel
        use_prefix :iframe

        DEFAULT_MAX_ENTRY_SIZE = 50 * 1024 * 1024   # 50MB

        WORDML_NS = { w: 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }.freeze

        has_string_attribute :url
        has_string_attribute :data

        attr_reader :iframe_ignorables
        attr_reader :iframe_namespaces
        attr_reader :iframe_numbering
        attr_reader :iframe_relationships

        attr_reader :document

        def initialize(args={}, &block)
          options = args.dup
          @document = options.delete :document
          super options, &block
        end

        # The largest single entry Caracal will read out of an embedded
        # document. Zip entries expand to many times their stored size, so
        # without a limit a small file can exhaust memory. Set to nil to
        # disable the check.
        def self.max_entry_size
          defined?(@max_entry_size) ? @max_entry_size : DEFAULT_MAX_ENTRY_SIZE
        end

        def self.max_entry_size=(value)
          @max_entry_size = value
        end

        # Reads a single entry from an embedded document, refusing anything
        # larger than max_entry_size. rubyzip does not stop reading at an
        # entry's declared size, so the bytes read are counted as well.
        def self.read_entry(entry)
          limit = max_entry_size
          if limit and entry.size > limit
            raise Caracal::Errors::InvalidModelError, "iframe entry #{entry.name} is #{entry.size} bytes, over the #{limit} byte limit."
          end

          content = entry.get_input_stream.read(limit && limit + 1) || ''.b
          if limit and content.bytesize > limit
            raise Caracal::Errors::InvalidModelError, "iframe entry #{entry.name} is larger than its declared #{entry.size} bytes, over the #{limit} byte limit."
          end

          content
        end

        #=============== PROCESSING =======================

        def preprocess!
          ::Zip::File.open(file) do |zip|
            # locate relationships xml
            entry      = zip.glob('word/_rels/document.xml.rels').first
            content    = self.class.read_entry entry
            rel_xml    = Nokogiri::XML(content)

            # locate document xml
            entry      = zip.glob('word/document.xml').first
            content    = self.class.read_entry entry
            doc_xml    = Nokogiri::XML(content)

            # master nodesets
            rel_nodes = rel_xml.children.first.children
            doc_root  = doc_xml.at_xpath('//w:document')
            pic_nodes = doc_xml.xpath('//pic:pic', { pic: 'http://schemas.openxmlformats.org/drawingml/2006/picture' })

            # namespaces
            @iframe_namespaces = doc_root.namespaces

            # ignorable namespaces
            if a = doc_root.attributes['Ignorable']
              @iframe_ignorables = a.value.split(/\s+/)
            end

            # relationships
            media_map = rel_nodes.reduce({}) do |hash, node|
              type = node.at_xpath('@Type').value
              if type.slice(-5, 5) == 'image'
                id   = node.at_xpath('@Id').value
                path = "word/#{ node.at_xpath('@Target').value }"
                hash[id] = path
              end
              hash
            end

            @iframe_relationships = pic_nodes.reduce([]) do |array, node|
              r_node  = node.children[1].children[0]
              r_id    = r_node.attributes['embed'].value.to_s
              r_media = media_map[r_id]

              p_node  = node.children[0].children[0]
              p_id    = p_node.attributes['id'].to_s.to_i
              p_name  = p_node.attributes['name'].to_s
              p_data  = self.class.read_entry zip.glob(r_media).first

              # register relationship
              array << { id: r_id, type: 'image', target: p_name, data: p_data }
              array
            end

            # hyperlinks to external targets; a link to a bookmark has no
            # relationship and keeps its w:anchor
            link_map = rel_nodes.each_with_object({}) do |node, hash|
              if node['Type'].to_s.end_with?('/hyperlink') and node['TargetMode'] == 'External'
                hash[node['Id']] = node['Target']
              end
            end

            link_ns  = { w: 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                         r: 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' }
            link_ids = doc_xml.xpath('//w:hyperlink/@r:id', link_ns).map(&:value).uniq
            link_ids.each do |r_id|
              @iframe_relationships << { id: r_id, type: 'link', target: link_map[r_id] } if link_map.key?(r_id)
            end

            # numbering definitions of the embedded lists
            if (entry = zip.glob('word/numbering.xml').first)
              @iframe_numbering = used_numbering doc_xml, Nokogiri::XML(self.class.read_entry(entry))
            end
          end
        end

        # The embedded numbering definitions under new ids, taken from the
        # block: each w:num gets one, and each w:abstractNum the id of the
        # first w:num pointing at it. Returns the map from old to new numIds
        # and the numbering part holding the renumbered definitions, which is
        # nil when the embedded paragraphs use none. The model stays as it is.
        def renumbered_numbering
          return [{}, nil] if iframe_numbering.nil?

          xml          = Nokogiri::XML(iframe_numbering)
          num_ids      = {}
          abstract_ids = {}

          xml.root.xpath('w:num', WORDML_NS).each do |num|
            num_id      = num.at_xpath('@w:numId', WORDML_NS)
            abstract_id = num.at_xpath('w:abstractNumId/@w:val', WORDML_NS)
            new_id      = yield.to_s

            num_ids[num_id.value]            = new_id
            abstract_ids[abstract_id.value] ||= new_id
            num_id.value                     = new_id
            abstract_id.value                = abstract_ids[abstract_id.value]
          end

          xml.root.xpath('w:abstractNum/@w:abstractNumId', WORDML_NS).each do |abstract_id|
            abstract_id.value = abstract_ids[abstract_id.value]
          end

          [num_ids, xml]
        end


        #=============== GETTERS ==========================

        def file
          @file ||= begin
            content = iframe_url.to_s.empty? ? iframe_data : Caracal::Utilities.read_resource(iframe_url)
            file    = Tempfile.new ['iframe', '.docx']
            file.binmode
            file.write content
            file.close    # flushes the write; rubyzip reopens by path
            file
          end
        end

        def ignorables
          @iframe_ignorables || []
        end

        def namespaces
          @iframe_namespaces || {}
        end

        def relationships
          @iframe_relationships || []
        end

        #=============== VALIDATION =======================

        def valid?
          if iframe_data
            validate_presence :data
          else
            validate_presence :url
          end
        end

        private

        def option_keys
          [:url, :data]
        end

        # The embedded numbering part, reduced to the w:num elements the
        # embedded paragraphs use and the w:abstractNum elements they point
        # at, in order of first use; nil when they use none. Picture bullets
        # and nsids stay behind: the pictures live in the part's own
        # relationships, and copies of a definition must not share its nsid.
        def used_numbering(doc_xml, num_xml)
          root      = num_xml.root or return
          abstracts = root.xpath('w:abstractNum[@w:abstractNumId]', WORDML_NS).to_h {|node| [node.at_xpath('@w:abstractNumId', WORDML_NS).value, node] }
          nums      = root.xpath('w:num[@w:numId]', WORDML_NS).to_h {|node| [node.at_xpath('@w:numId', WORDML_NS).value, node] }

          used = doc_xml.xpath('//w:numPr/w:numId/@w:val', WORDML_NS).map(&:value).uniq.filter_map do |id|
            num      = nums[id] or next
            abstract = abstracts[num.at_xpath('w:abstractNumId/@w:val', WORDML_NS)&.value] or next
            [abstract, num]
          end
          return if used.empty?

          root.children.each(&:unlink)
          (used.map(&:first).uniq + used.map(&:last)).each {|node| root << node }
          root.xpath('.//w:nsid | .//w:lvlPicBulletId', WORDML_NS).each(&:unlink)

          num_xml.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML).freeze
        end

      end
    end
  end
end
