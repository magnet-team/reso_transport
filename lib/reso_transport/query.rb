module ResoTransport
  Query = Struct.new(:resource) do

    def all(&block)
      new_query_context('and')
      instance_eval(&block)
      clear_query_context
      return self
    end

    def any(&block)
      new_query_context('or')
      instance_eval(&block)
      clear_query_context
      return self
    end

    [:eq, :ne, :gt, :ge, :lt, :le].each do |op|
      define_method(op) do |conditions|
        conditions.each_pair do |k,v|
          current_query_context << "#{k} #{op} #{parse_value(k, v)}"
        end
        return self
      end
    end

    def limit(size)
      options[:top] = size
      return self
    end

    def offset(size)
      options[:skip] = size
      return self
    end

    def order(field, dir=nil)
      options[:orderby] = [field, dir].join(" ").strip
      return self
    end

    def include_count
      options[:count] = true
      return self
    end

    def select(*fields)
      os = options.fetch(:select, "").split(",")
      options[:select] = (os + Array(fields)).uniq.join(",")

      return self
    end

    def include(*names)
      ex = options.fetch(:expand, "").split(",")
      options[:expand] = (ex + Array(names)).uniq.join(",")

      return self
    end

    def results
      execute[:results]
    end

    def execute
      resp = resource.get(compile_params)
      parsed_body = JSON.parse(resp.body)
      results = parsed_body.delete("value")

      {
        success: resp.success? && !parsed_body.has_key?("error"),
        meta: parsed_body,
        results: resource.parse(results)
      }
    end

    def new_query_context(context)
      @last_query_context ||= 0
      @current_query_context = @last_query_context + 1
      sub_queries[@current_query_context][:context] = context
    end

    def clear_query_context
      @last_query_context = @current_query_context
      @current_query_context = nil
    end

    def current_query_context
      @current_query_context ||= nil
      sub_queries[@current_query_context || :global][:criteria]
    end

    def options
      @options ||= {}
    end

    def sub_queries
      @sub_queries ||= Hash.new {|h,k| h[k] = { context: 'and', criteria: [] } }
    end

    def compile_filters
      groups = sub_queries.dup
      global = groups.delete(:global)
      filter_groups = groups.values

      filter_string = ""

      if global && global[:criteria]&.any?
        filter_string << global[:criteria].join(" #{global[:context]} ")  
      end

      filter_string << filter_groups.map do |g|
        "(#{g[:criteria].join(" #{g[:context]} ")})"
      end.join(" and ")

      filter_string
    end

    def compile_params
      params = {}

      options.each_pair do |k,v|
        params["$#{k}"] = v
      end

      if !sub_queries.empty?
        params["$filter"] = compile_filters
      end

      params
    end

    def parse_value(key, v)
      field = resource.property(key.to_s)
      raise "Couldn't find property #{key} for #{resource.name}" if field.nil?
      field.parse_query_value(v)
    end

  end
end
