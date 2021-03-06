module ResoTransport
  Metadata = Struct.new(:client) do 

    MIME_TYPES = {
      xml: "application/xml",
      json: "application/json"
    }

    def entity_sets
      parser.entity_sets
    end

    def schemas
      parser.schemas
    end

    def parser
      @parser ||= MetadataParser.new.parse(get_data)
    end

    def md_cache
      @md_cache ||= client.md_cache.new(client.md_file)
    end

    def get_data
      if client.md_file 
        md_cache.read || md_cache.write(raw)
      else
        raw
      end
    end

    def raw
      resp = client.connection.get("$metadata") do |req|
        req.headers['Accept'] = MIME_TYPES[client.vendor.fetch(:metadata_format, :xml).to_sym]
      end

      if resp.success?
        resp.body
      else
        puts resp.body
        raise "Error getting metadata!"
      end
    end

  end
end
