require 'colorize'
require_relative 'helpers/componenthelper'
require_relative 'helpers/statushelper'
require_relative 'messages/errors'
require_relative 'domain/feature/feature'
require_relative 'domain/scenario/scenario'
require_relative 'domain/story/story'

class Hash

  def include_mode
    self[:include_mode].nil? ? :none : self[:include_mode]
  end

  def rootpath
    (self[:rootpath].nil? || self[:rootpath].empty?) ? Dir.pwd : self[:rootpath]
  end

  def ids_selection
    self[:select].nil? ? [] : self[:select].is_a?(Array) ? self[:select] : [self[:select]]
  end

end

module Marso

  # options: Hash defined as follow
  #    :rootpath => Path of the folder containing the 'stories' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single story's id or Array of story's ids. The execution
  #               of stories will be restricted to those ids only
  #    :include_mode => Symbol that defines what should be included in the
  #                     feature's description. Possible values are:
  #         => :none - (Default) Only display the feature's description
  #         => :with_stories - Display the feature description as well as all its
  #                            stories' description
  #         => :with_stories_scenarios - Display the feature description as well
  #                                      as all its stories' description
  #                                      (including their scenarios)
  #         => :with_scenarios - Display the feature description as well as all its
  #                              scenarios' description
  #         => :with_all - Display the feature description as well as both all its
  #                        stories(including their scenarios) and scenarios descriptions
  def self.run_features(options={})
    options[:include_mode] = :with_all

    Marso.core_components_query(:feature, options)
      .select_many { |f| f.all_scenario_contexts }
      .select { |scn| scn.run }
      .execute
  end

  def self.run_features_async(options={})
    options[:include_mode] = :with_all

    all_features = Marso.core_components_query(:feature, options).to_a
    _all_feat = Enumerate.from(all_features)
    all_stories = _all_feat.select_many { |f| f.stories }.to_a
    all_scenario_ctxs = _all_feat.select_many { |f| f.all_scenario_contexts }.to_a

    scenarios_per_features = Hash[all_features
      .reject { |f| f.scenario_contexts.empty? }
      .group_by { |f| f.id }
      .map { |f_id, f|
        [
          f_id, # Hash key
          {     # Hash value
            :scenarios => f[0].scenario_contexts.map { |scn| {:processed => false, :id => scn.id, :original_scn => scn}},
            :original_feature => f[0],
            :processed => false
          }
        ]}]

    scenarios_per_stories = Hash[all_stories
      .reject { |s| s.scenario_contexts.empty? }
      .group_by { |s| s.id }
      .map { |s_id, s|
        [
          s_id, # Hash key
          {     # Hash value
            :scenarios => s[0].scenario_contexts.map { |scn| {:processed => false, :id => scn.id, :original_scn => scn}},
            :original_story => s[0],
            :processed => false
          }
        ]}]

    stories_per_features = Hash[all_features
      .reject { |f| f.stories.empty? }
      .group_by { |f| f.id }
      .map { |f_id, f|
        [
          f_id, # Hash key
          {     # Hash value
            :stories => f[0].stories.map { |s| {:processed => false, :id => s.id }},
            :processed => false
          }
        ]}]

    features_with_status = Hash[all_features.map { |f|
      [
        f.id, # Hash key
        {     # Hash value
          :original_feature => f,
          :processed => false
        }
      ]}]

    task_size = all_scenario_ctxs.size
    updated_scenario_ctxs = []

    EM.run do
      all_scenario_ctxs.each { |scn|
        EM.defer(
          proc { scn.run },
          lambda { |updated_scenario_ctx|
            updated_scenario_ctxs << updated_scenario_ctx
            task_size -= 1
            EM.stop if task_size < 1

            puts updated_scenario_ctx.indented_colorized_text
            scn_id = updated_scenario_ctx.id
            story_id = updated_scenario_ctx.story_id
            feat_id = updated_scenario_ctx.feature_id
            scenarios_per_story = scenarios_per_stories[story_id]
            scenarios_per_feat = scenarios_per_features[feat_id]
            stories_per_feat = stories_per_features[feat_id]
            feature_with_status = features_with_status[feat_id]
            story_completed = false
            feature_completed = false
            unless scenarios_per_story.nil?
              item = scenarios_per_story[:scenarios].detect { |scn| scn[:id] == scn_id }
              unless item.nil?
                item[:processed] = true
                item[:updated_scn] = updated_scenario_ctx
                story_completed = scenarios_per_story[:scenarios].all? { |scn| scn[:processed] }
                if story_completed
                  # 1. Update the story
                  scenarios_per_story[:processed] = true
                  original_story = scenarios_per_story[:original_story]
                  udt_story_desc = original_story.description.clone
                  udt_story_ctx = original_story.ctx.clone
                  udt_story_desc[:scenario_contexts] = scenarios_per_story[:scenarios].map { |scn| scn[:updated_scn]}
                  updated_story = Marso::Story.new(udt_story_desc, udt_story_ctx)
                  puts updated_story.indented_colorized_text
                  scenarios_per_story[:updated_story] = updated_story
                  unless stories_per_feat.nil? # 2. Cascade the new story status upon the feature
                    # 2.1. Update the status of the story under the feature
                    story_item = stories_per_feat[:stories].detect { |s| s[:id] == story_id }
                    unless story_item.nil?
                      story_item[:processed] = true
                      # 2.2. Check all stories under that feature are noew completed
                      all_stories_for_that_feature_completed = stories_per_feat[:stories].all? { |s| s[:processed] }
                      if all_stories_for_that_feature_completed
                        stories_per_feat[:processed] = true
                        # 2.3. Check if that feature is now fully completed
                        feature_completed = scenarios_per_feat.nil? || scenarios_per_feat[:processed]
                        if feature_completed
                          feature_with_status[:processed] = true
                          original_feature = feature_with_status[:original_feature]
                          udt_feat_desc = original_feature.description.clone
                          udt_feat_ctx = original_feature.ctx.clone
                          # 2.3.1. Update feature with all updated stories
                          unless stories_per_feat.nil?
                            feat_story_ids = stories_per_feat[:stories].map { |s| s[:id]}
                            upt_stories = scenarios_per_stories
                              .select { |s_id| feat_story_ids.include?(s_id) }
                              .values.map { |x| x[:updated_story] }
                            udt_feat_desc[:stories] = upt_stories
                          end
                          # 2.3.2. Update feature with all updated scenarios
                          unless scenarios_per_feat.nil?
                            udt_feat_desc[:scenario_contexts] = scenarios_per_feat[:scenarios].map { |scn| scn[:updated_scn]}
                          end
                          updated_feature = Marso::Feature.new(udt_feat_desc, udt_feat_ctx)
                          puts updated_feature.indented_colorized_text
                          feature_with_status[:updated_feature] = updated_feature
                        end
                      end
                    end
                  end
                end
              end
            end

            unless scenarios_per_feat.nil?
              item = scenarios_per_feat[:scenarios].detect { |scn| scn[:id] == scn_id }
              unless item.nil?
                item[:processed] = true
                item[:updated_scn] = updated_scenario_ctx
                all_scenarios_for_that_feature_completed = scenarios_per_feat[:scenarios].all? { |scn| scn[:processed] }
                if all_scenarios_for_that_feature_completed
                  # 1. Update the feature
                  scenarios_per_feat[:processed] = true
                  # 2. Check if that feature is now fully completed
                  feature_completed = stories_per_feat.nil? || stories_per_feat[:processed]
                  if feature_completed
                    feature_with_status[:processed] = true
                    original_feature = feature_with_status[:original_feature]
                    udt_feat_desc = original_feature.description.clone
                    udt_feat_ctx = original_feature.ctx.clone
                    # 2.2.1. Update feature with all updated stories
                    unless stories_per_feat.nil?
                      feat_story_ids = stories_per_feat[:stories].map { |s| s[:id]}
                      upt_stories = scenarios_per_stories
                        .select { |s_id| feat_story_ids.include?(s_id) }
                        .values.map { |x| x[:updated_story] }
                      udt_feat_desc[:stories] = upt_stories
                    end
                    # 2.2.2. Update feature with all updated scenarios
                    unless scenarios_per_feat.nil?
                      udt_feat_desc[:scenario_contexts] = scenarios_per_feat[:scenarios].map { |scn| scn[:updated_scn]}
                    end
                    updated_feature = Marso::Feature.new(udt_feat_desc, udt_feat_ctx)
                    puts updated_feature.indented_colorized_text
                    feature_with_status[:updated_feature] = updated_feature
                  end
                end
              end
            end
        })
      }
    end
  end

  # options: Hash defined as follow
  #    :rootpath => Path of the folder containing the 'stories' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single story's id or Array of story's ids. The execution
  #               of stories will be restricted to those ids only
  #    :include_mode => Symbol that defines what should be included in the
  #                     feature's description. Possible values are:
  #         => :none - (Default) Only display the feature's description
  #         => :with_stories - Display the feature description as well as all its
  #                            stories' description
  #         => :with_stories_scenarios - Display the feature description as well
  #                                      as all its stories' description
  #                                      (including their scenarios)
  #         => :with_scenarios - Display the feature description as well as all its
  #                              scenarios' description
  #         => :with_all - Display the feature description as well as both all its
  #                        stories(including their scenarios) and scenarios descriptions
  def self.show_features_text(options={})
    Marso.core_components_query(:feature, options)
      .select { |f| puts f.indented_colorized_details(options.include_mode) }
      .execute
  end

  # options: Hash defined as follow
  #    :rootpath => Path of the folder containing the 'stories' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single story's id or Array of story's ids. The execution
  #               of stories will be restricted to those ids only
  #    :include_mode => Symbol that defines what should be included in the
  #                     feature's description. Possible values are:
  #         => :none - (Default) Only display the feature's description
  #         => :with_scenarios - Display the feature description as well as all its
  #                              scenarios' description
  def self.show_stories_text(options={})
    Marso.core_components_query(:story, options)
      .select { |s| puts s.indented_colorized_details(options.include_mode) }
      .execute
  end

  # options: Hash defined as follow
  #    :rootpath => Path of the folder containing the 'stories' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single story's id or Array of story's ids. The execution
  #               of stories will be restricted to those ids only
  def self.show_scenarios_text(options={})
    Marso.core_components_query(:scenario_context, options)
      .select { |s| puts s.indented_colorized_text }
      .execute
  end

  # options: Hash defined as follow
  #    :rootpath => Path of the folder containing the 'stories' folder. If not
  #                 specified, then the default is to set it to the current
  #                 caller's location
  #    :select => Single story's id or Array of story's ids. The execution
  #               of stories will be restricted to those ids only
  #    :include_mode => Symbol that defines what should be included in the
  #                     feature's description. Possible values are:
  #         => :none - (Default) Only display the feature's description
  #         => :with_stories - Display the feature description as well as all its
  #                            stories' description
  #         => :with_stories_scenarios - Display the feature description as well
  #                                      as all its stories' description
  #                                      (including their scenarios)
  #         => :with_scenarios - Display the feature description as well as all its
  #                              scenarios' description
  #         => :with_all - Display the feature description as well as both all its
  #                        stories(including their scenarios) and scenarios descriptions
  def self.core_components_query(component_type, options={})
    file_pattern = nil

    case component_type
    when :feature
      file_pattern = 'features/*/*.rb'
    when :story
      file_pattern = 'stories/*/*.rb'
    when :scenario_context
      file_pattern = 'scenarios/*.rb'
    else
      raise ArgumentError, ":#{component_type} is not a valid component_type. " +
      "Valid types are #{[:feature, :story, :scenario_context].join(', ')}"
    end

    file_path_pattern = File.join(options.rootpath, file_pattern)
    load_mode = options.include_mode.to_load_mode

    components = Marso.components(component_type, file_path_pattern)
    ids_selection = options.ids_selection

    query =  ids_selection.any? ? components.where { |x| ids_selection.include?(x.id) } : components

    if component_type == :scenario_context
      return query
    else
      return query.select { |c| c.load(load_mode) }
    end
  end
end
