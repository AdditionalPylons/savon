require "nori"

class Savon
  class Response

    def initialize(raw_response, snakecase = true)
      @raw_response = raw_response
      @snakecase = snakecase
    end

    def raw
      @raw_response
    end

    def body
      return (@snakecase ? hash[:envelope][:body] : hash[:Envelope][:Body]) if hash
      nil
    end
    alias to_hash body

    def header
      return (@snakecase ? hash[:envelope][:header] : hash[:Envelope][:Header]) if hash
      nil
    end

    def hash
      @hash ||= nori.parse(raw)
    end

    def doc
      @doc ||= Nokogiri.XML(raw)
    end

    def xpath(path, namespaces = nil)
      doc.xpath(path, namespaces || xml_namespaces)
    end

    private

    def nori
      return @nori if @nori

      nori_options = {
        strip_namespaces: true,
        convert_tags_to: lambda { |tag| 
          @snakecase ? tag.snakecase.to_sym : tag.to_sym }
      }

      non_nil_nori_options = nori_options.reject { |_, value| value.nil? }
      @nori = Nori.new(non_nil_nori_options)
    end

  end
end
