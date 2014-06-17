require 'colorize'
require_relative '../../helpers/texthelper'

module Marso
  module FeaturePublish
    include TextHelper

    def colorized_text
      self.text.colorize(self.color_theme)
    end

    # include_mode => Symbol that defines what should be included in the
    #                 feature's description. Possible values are:
    #   :none - (Default) Only display the feature's description
    #   :with_stories - Display the feature description as well as all its
    #                   stories' description
    #   :with_stories_scenarios - Display the feature description as well
    #                             as all its stories' description
    #                             (including their scenarios)
    #   :with_scenarios - Display the feature description as well as all its
    #                     scenarios' description
    #   :with_all - Display the feature description as well as both all its
    #               stories(including their scenarios) and scenarios descriptions
    def indented_colorized_details(include_mode=:none)

      get_scenario_ctxs_text_a = lambda { |f|
        f.scenario_contexts.map { |scn| scn.indented_colorized_text }
      }

      get_stories_text_a = lambda { |f|
        f.stories.map { |s| s.indented_colorized_text }
      }

      get_stories_scenarios_text_a = lambda { |f|
        f.stories.map { |s|
          [s.indented_colorized_text]
            .concat(s.scenario_contexts # add scenarios' text under each story
              .map { |scn| scn.indented_colorized_text })
            .join("\n") }
      }

      get_indented_colored_text = lambda { |f|
        case include_mode
        when :none
          f.indented_colorized_text
        when :with_scenarios
          [f.indented_colorized_text]
            .concat(get_scenario_ctxs_text_a.call(f)) # add scenarios' text under each feat
            .join("\n")
        when :with_stories
          [f.indented_colorized_text]
            .concat(get_stories_text_a.call(f)) # add stories' text under each feat
            .join("\n")
        when :with_stories_scenarios
          [f.indented_colorized_text]
            .concat(get_stories_scenarios_text_a.call(f)) # add stories' text under each feat
            .join("\n")
        when :with_all
          [f.indented_colorized_text]
            .concat(get_scenario_ctxs_text_a.call(f)) # add scenarios' text under each feat
            .concat(get_stories_scenarios_text_a.call(f)) # add stories' text under each feat
            .join("\n")
        else
          raise ArgumentError, ":#{include_mode} is not a valid argument. " +
          "Please choose one of the following:\n" +
          "- #{[:none, :with_scenarios, :with_stories, :with_stories_scenarios, :with_all].join('\n- ')}"
        end
      }

      return get_indented_colored_text.call(self)
    end
  end
end
