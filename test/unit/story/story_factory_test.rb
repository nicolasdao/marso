require 'test_helper'

describe Marso::StoryFactory do
	subject { Marso::StoryFactory.new }
	let(:new_story) { Fixtures['create_new_story_file']['story'] }
	let(:stories_root) { Pathname("../tmp").expand_path(__FILE__) }

	before do
		FileUtils.remove_dir stories_root, true 	# Delete folder
		FileUtils.mkdir stories_root				# Create folder
	end

	after do
		FileUtils.remove_dir stories_root, true
	end
	
	it "Creates a .rb story file that contains the story details" do
		feature_file = subject.create_story_file({
			:id => new_story['id'],
 			:name => new_story['name'],
 			:in_order_to => new_story['in_order_to'],
 			:as_a => new_story['as_a'],
 			:i => new_story['i']
		}, stories_root)

		require File.join(stories_root, feature_file)
		s = MarsoContext.story

		s.id.must_equal new_story['id']
		s.name.must_equal new_story['name']
		s.description[:in_order_to].must_equal new_story['in_order_to']
		s.description[:as_a].must_equal new_story['as_a']
		s.description[:i].must_equal new_story['i']
	end

end