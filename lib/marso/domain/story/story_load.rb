require_relative '../../helpers/componenthelper'

module Marso
  module StoryLoad

    def load(mode=:scenario_contexts)
      new_ctx = self.ctx.clone
      new_ctx[:story_id] = self.id
      file_path_pattern = File.join(self.rootpath, 'scenarios/*.rb')

      scenario_ctxs = Marso.load_components(:scenario_context, file_path_pattern, new_ctx)

      new_description = self.description.clone
      new_description[:scenario_contexts] = scenario_ctxs
      return Story.new(new_description, new_ctx)
    end
  end
end
