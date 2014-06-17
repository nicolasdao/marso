require 'colorize'
require_relative '../../helpers/texthelper'

module Marso
  module ScenarioPublish
    include TextHelper

    def colorized_text
      scen_parts = [self.header.colorize(self.color_theme) + ": " + "#{self.name}".blue]
      if !@steps.nil?
        (scen_parts | @steps.map { |s| s.colorized_text(include_id=true)  }).join("\n")
      else
        scen_parts[0]
      end
    end
  end
end
