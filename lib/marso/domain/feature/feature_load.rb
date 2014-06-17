require_relative '../../helpers/componenthelper'

module Marso
  module FeatureLoad

    # Load feature's components based on the following mode:
    # => :none
    # => :stories
    # => :stories_with_scenarios
    # => :scenario_contexts
    # => :all
    def load(mode)
      case mode
      when :none
          return self
      when :stories
        return load_stories
      when :stories_with_scenarios
        return load_stories :with_scenarios
      when :scenario_contexts
        return load_scenario_contexts
      when :all
        return self.load(:stories_with_scenarios).load(:scenario_contexts)
      else
        raise ArgumentError, "Mode #{mode} is not supported. Use one of the following: :stories, :scenario_contexts, :all"
      end
    end

    private

      def load_scenario_contexts
        new_ctx = @ctx.clone
        new_ctx[:feature_id] = @id
        file_path_pattern = File.join(@rootpath, 'scenarios/*.rb')

        scenario_ctxs = Marso.load_components(:scenario_context, file_path_pattern, new_ctx)

        new_description = @description.clone
        new_description[:scenario_contexts] = scenario_ctxs
        return Feature.new(new_description, new_ctx)
      end

      # include_mode (optional):
      # => :none - (Default) Only display the story's description
      # => :with_scenarios - Display the story's description as well as all its
      #                      scenarios' description
      def load_stories(include_mode=:none)
        new_ctx = @ctx.clone
        new_ctx[:feature_id] = @id
        file_path_pattern = File.join(@rootpath, 'stories/*/*.rb')

        stories = Marso.load_components(:story, file_path_pattern, new_ctx)
          .map { |s| include_mode == :with_scenarios ? s.load(:scenario_contexts) : s}

        new_description = @description.clone
        new_description[:stories] = stories
        return Feature.new(new_description, new_ctx)
      end
  end
end
