
module Marso
  module Messages

    def self.no_component_found(component_type, rootpath)
      component_name = proc {
        case component_type
        when :feature
          "features"
        when :story
          "stories"
        when :scenario
          "scenarios"
        else
          raise ArgumentError, ":#{component_type} is not a valid component_type. " +
          "Valid values are: #{[:feature, :story, :scenario].join(', ')}"
        end
      }

      "E0000: No #{component_name.call} were found under path '#{rootpath}'.\n" +
      "Browse to a different folder, or use the :rootpath option to define an adequate path"
    end

    def self.no_component_match(component_type, offenders)
      "E0001: The following selected #{component_type} ids couldn't be found: #{offenders.join(', ')}"
    end

  end
end
