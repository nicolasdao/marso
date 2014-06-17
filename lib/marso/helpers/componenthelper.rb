require_relative "../toolbelt/fiberpiping"

module Marso

  # component_type:
  #   :feature
  #   :story
  #   :scenario_context
  def self.load_components(component_type, file_path_pattern, ctx={})
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

  # component_type:
  #   :feature
  #   :story
  #   :scenario_context
  def self.components(component_type, file_path_pattern, ctx={})
    Enumerate.from(Dir[file_path_pattern])
      .where { |file|
        load file
        Object.const_defined?("MarsoContext") && Object.const_get("MarsoContext").respond_to?(component_type)
      }
      .select { |file|
        component = Object.const_get("MarsoContext").send(component_type, ctx)
        class_name = component_type.to_s.split("_").map { |x| x.capitalize }.join
        raise ArgumentError, "Method MarsoContext.#{component_type} cannot return nil" if component.nil?
        raise ArgumentError, "Method MarsoContext.#{component_type} must return an object of class Marso::Story" unless component.class.to_s == "Marso::#{class_name}"
        component
      }
  end


  # This method reorganized a collection of scenario contexts so they are
  # regrouped under their parent components(origin_stories or origin_features).
  # The stories that results from that reorganization will also be regrouped
  # under their respective features
  # Arguments:
  #   - scenario_contexts: Array of scenarios contexts that need to be
  #                        reorganized
  #   - origin_stories: Array of stories OR single story, that are a known
  #                     parent of some of the scenario_contexts
  #   - origin_features: Array of features OR single feature, that are a known
  #                      parent of some of the scenario_contexts
  def self.reorganize_scenariocontexts_into_components(scenario_contexts, origin_stories, origin_features)
    original_features = origin_features.is_a?(Array) ? origin_features : [origin_features]
    original_stories = origin_stories.is_a?(Array) ? origin_stories : [origin_stories]

    updated_stories = []
    scenario_contexts_per_feature_ids = []
    features_updated_with_stories = []
    updated_features = []

    scenario_contexts
      .group_by { |x| x.story_id }
      .each { |k,v|
        if k != nil # scenarios which belong to stories
          story = original_stories.detect { |x| x.id == k }
          updated_story_description = story.description.clone
          updated_story_description[:scenario_contexts] = v
          updated_story_ctx = story.ctx.clone
          updated_story = Story.new(updated_story_description, updated_story_ctx)
          updated_stories << updated_story
        else # scenarios which do not belong to any stories, and therefore probably belong straight to a feature
          scenario_contexts_per_feature_ids = v.group_by { |y| y.feature_id }
        end
      }

    # Update original stories that seem to not have any scenario_contexts associated with them
    original_stories.each { |s|
      unless updated_stories.any? { |x| x.id == s.id }
        new_description = s.description.clone
        new_description[:status] = :failed_no_scenarios
        updated_stories << Marso::Story.new(new_description, s.ctx)
      end
    }

    # Regroup updated stories under their respective features
    updated_stories
      .group_by { |x| x.feature_id }
      .each { |k,v|
        if k != nil # stories which belong to features
          feat = original_features.detect { |x| x.id == k }
          updated_feat_description = feat.description.clone
          updated_feat_description[:stories] = v
          updated_feat_ctx = feat.ctx.clone
          updated_feat = Feature.new(updated_feat_description, updated_feat_ctx)
          features_updated_with_stories << updated_feat
        else
          # not sure what to do yet. Normally, scenario_contexts with no feature
          # or story associated with them should not happen
        end
      }

    # Add all the original features that do not contain any updated stories
    # to the list of updated features. This is needed so that the updated features
    # list contain all the orignial features so that we can use it for the next step
    original_features.each { |x|
      (features_updated_with_stories << x) unless features_updated_with_stories.any? { |y| y.id == x.id }
    }

    # Regroup scenario contexts that are not associated with any stories under
    # their respective feature
    updated_features = features_updated_with_stories.map { |x|
      if scenario_contexts_per_feature_ids.key?(x.id) # found scenarios for this feature
        new_description = x.description.clone
        new_description[:scenario_contexts] = scenario_contexts_per_feature_ids[x.id]
        new_ctx = x.ctx.clone
        Feature.new(new_description, new_ctx)
      else # no scenarios for this feature. Check if it has stories, otherwise flag it as failed
        if x.stories.any?
          x
        else
         new_description = x.description.clone
         new_description[:status] = :failed_no_component
         new_ctx = x.ctx.clone
         Feature.new(new_description, new_ctx)
       end
      end
    }

    return [updated_features, updated_stories]
  end

end
