
module Marso

  def self.load_component(component_type, file_path_pattern, ctx={})
    components = []

    Dir[file_path_pattern].each { |file|

      load file

      file_contains_marso_component = Object.const_defined?("MarsoContext") && Object.const_get("MarsoContext").respond_to?(component_type)

      if file_contains_marso_component
        component = Object.const_get("MarsoContext").send(component_type, ctx)
        class_name = component_type.to_s.split("_").map { |x| x.capitalize }.join
        raise ArgumentError, "Method MarsoContext.#{component_type} cannot return nil" if component.nil?
        raise ArgumentError, "Method MarsoContext.#{component_type} must return an object of class Marso::Story" unless component.class.to_s == "Marso::#{class_name}"

        components << component
      end
    }

    return components
  end

end
