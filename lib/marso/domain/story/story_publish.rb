require 'colorize'
require_relative '../../helpers/texthelper'

module Marso
  module StoryPublish
    include TextHelper

    def colorized_text
      self.text.colorize(self.color_theme)
    end

    # include_mode => Symbol that defines what should be included in the
    #                 feature's description. Possible values are:
    #   :none - (Default) Only display the feature's description
    #   :with_scenarios - Display the feature description as well as all its
    #                     scenarios' description
    def indented_colorized_details(include_mode=:none)

      get_scenario_ctxs_text_a = lambda { |s|
        s.scenario_contexts.map { |scn| scn.indented_colorized_text }
      }

      get_indented_colored_text = lambda { |s|
        case include_mode
        when :none
          s.indented_colorized_text
        when :with_scenarios
          [s.indented_colorized_text]
            .concat(get_scenario_ctxs_text_a.call(s)) # add scenarios' text under each feat
            .join("\n")
        else
          raise ArgumentError, ":#{include_mode} is not a valid argument. " +
          "Please choose one of the following:\n" +
          "- #{[:none, :with_scenarios].join('\n- ')}"
        end
      }

      return get_indented_colored_text.call(self)
    end
  end
end
