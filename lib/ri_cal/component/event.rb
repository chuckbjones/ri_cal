require File.join(File.dirname(__FILE__), %w[.. properties event.rb])

module RiCal
  class Component
    # An Event (VEVENT) calendar component groups properties describing a scheduled event.
    # Events may have multiple occurrences
    #
    # Events may also contain one or more ALARM subcomponents
    #
    # to see the property accessing methods for this class see the RiCal::Properties::Event module
    # to see the methods for enumerating occurrences of recurring events see the RiCal::OccurrenceEnumerator module
    class Event < Component
      include OccurrenceEnumerator

      include RiCal::Properties::Event

      def subcomponent_class
        {:alarm => Alarm }
      end

      def self.entity_name #:nodoc:
        "VEVENT"
      end

    end
  end
end