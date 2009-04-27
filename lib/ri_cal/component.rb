module RiCal
  class Component    
    class ComponentBuilder #:nodoc:
      def initialize(component)
        @component = component
      end

      def method_missing(selector, *args, &init_block)
        if(sub_comp_class = @component.subcomponent_class[selector])
          if init_block
            sub_comp = sub_comp_class.new(@component)
            if init_block.arity == 1
              yield ComponentBuilder.new(sub_comp)
            else
              ComponentBuilder.new(sub_comp).instance_eval(&init_block)
            end
            self.add_subcomponent(sub_comp)
          end
        else
          sel = selector.to_s
          sel = "#{sel}=" unless /(^(add_)|(remove_))|(=$)/ =~ sel
          if @component.respond_to?(sel)
            @component.send(sel, *args)
          else
            super
          end
        end
      end
    end

    autoload :Timezone, "#{File.dirname(__FILE__)}/component/timezone.rb"

    def initialize(parent=nil, &init_block) #:nodoc: 
      @parent = parent
      if block_given?
        if init_block.arity == 1
          init_block.call(ComponentBuilder.new(self))
        else
          ComponentBuilder.new(self).instance_eval(&init_block)
        end
      end
    end
    
    def subcomponent_class #:nodoc:
      {}
    end

    def self.from_parser(parser, parent) #:nodoc:
      entity = self.new(parent)
      line = parser.next_separated_line
      while parser.still_in(entity_name, line)
        entity.process_line(parser, line)
        line = parser.next_separated_line
      end
      entity
    end

    def self.parse(io) #:nodoc:
      Parser.new(io).parse
    end

    def self.parse_string(string) #:nodoc:
      parse(StringIO.new(string))
    end

    def subcomponents #:nodoc:
      @subcomponents ||= Hash.new {|h, k| h[k] = []}
    end

    def entity_name #:nodoc:
      self.class.entity_name
    end

    # return an array of Alarm components within this component :nodoc:
    # Alarms may be contained within Events, and Todos
    def alarms
      subcomponents["VALARM"]
    end

    def add_subcomponent(component) #:nodoc:
      subcomponents[component.entity_name] << component
    end

    def parse_subcomponent(parser, line) #:nodoc:
      subcomponents[line[:value]] << parser.parse_one(line, self)
    end

    def process_line(parser, line) #:nodoc:
      if line[:name] == "BEGIN"
        parse_subcomponent(parser, line)
      else
        setter = self.class.property_parser[line[:name]]
        if setter
          send(setter, line)
        else
          self.add_x_property(PropertyValue::Text.new(line), line[:name])
        end
      end
    end

    # return a hash of any extended properties, (i.e. those with a property name starting with "X-"
    # representing an extension to the RFC 2445 specification)
    def x_properties
      @x_properties ||= {}
    end

    # Add a n extended property 
    def add_x_property(prop, name)
      x_properties[name] = prop
    end

    # Predicate to determine if the component is valid according to RFC 2445
    def valid?
      !mutual_exclusion_violation
    end

    def initialize_copy(original) #:nodoc:
    end

    def prop_string(prop_name, *properties) #:nodoc:
      properties = properties.flatten.compact
      if properties && !properties.empty?
        properties.map {|prop| "#{prop_name}#{prop.to_s}"}.join("\n")
      else
        nil
      end
    end

    def add_property_date_times_to(required_timezones, property) #:nodoc:
      if property
        if Array === property
          property.each do |prop|
            prop.add_date_times_to(required_timezones)
          end
        else
          property.add_date_times_to(required_timezones)
        end
      end
    end

    def export_prop_to(export_stream, name, prop) #:nodoc:
      if prop
        string = prop_string(name, prop)
        export_stream.puts(string) if string
      end
    end

    def export_x_properties_to(export_stream) #:nodoc:
      x_properties.each do |name, prop|
        export_stream.puts(prop_string(name, prop))
      end
    end

    def export_subcomponent_to(export_stream, subcomponent) #:nodoc:
      subcomponent.each do |component|
        component.export_to(export_stream)
      end
    end
    
    # return a string containing the rfc2445 format of the component
    def to_s
      io = StringIO.new
      export_to(io)
      io.string
    end

    # Export this component to an export stream
    def export_to(export_stream)
      export_stream.puts("BEGIN:#{entity_name}")
      export_properties_to(export_stream)
      subcomponents.values do |sub|
        export_subcomponent_to(export_subcomponent_to, sub)
      end
      export_stream.puts("END:#{entity_name}")
    end

    # Export this single component as an iCalendar component containing only this component and
    # any required additional components (i.e. VTIMEZONES referenced from this component)
    # if stream is nil (the default) then this method will return a string,
    # otherwise stream should be an IO to which the iCalendar file contents will be written
    def export(stream=nil)
      wrapper_calendar = Calendar.new
      wrapper_calendar.add_subcomponent(self)
      wrapper_calendar.export(stream)
    end
  end
end

Dir[File.dirname(__FILE__) + "/component/*.rb"].sort.each do |path|
  filename = File.basename(path)
  require path
end