require 'test_helper'

describe Marso::FeatureFactory do
	subject { Marso::FeatureFactory.new }
	let(:new_feature) { Fixtures['create_new_feature_file']['feature'] }
	let(:features_root) { Pathname("../tmp").expand_path(__FILE__) }

	before do
		FileUtils.remove_dir features_root, true 	# Delete folder
		FileUtils.mkdir features_root				# Create folder
	end

	after do
		FileUtils.remove_dir features_root, true
	end
	
	it "Creates a .rb feature file that contains the feature details" do
		feature_file = subject.create_feature_file({
			:id => new_feature['id'],
 			:name => new_feature['name'],
 			:in_order_to => new_feature['in_order_to'],
 			:as_a => new_feature['as_a'],
 			:i => new_feature['i']
		}, features_root)

		require File.join(features_root, feature_file)
		f = MarsoContext.feature

		f.id.must_equal new_feature['id']
		f.name.must_equal new_feature['name']
		f.description[:in_order_to].must_equal new_feature['in_order_to']
		f.description[:as_a].must_equal new_feature['as_a']
		f.description[:i].must_equal new_feature['i']
	end

end