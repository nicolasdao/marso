require 'test_helper'

describe Marso::ScenarioFactory do
	subject { Marso::ScenarioFactory.new }
	let(:new_scenario) { Fixtures['create_new_scenario_file']['scenario'] }
	let(:scenario_root) { Pathname("../tmp").expand_path(__FILE__) }

	before do
		FileUtils.remove_dir scenario_root, true 	# Delete folder
		FileUtils.mkdir scenario_root				# Create folder
	end

	after do
		FileUtils.remove_dir scenario_root, true
	end
	
	it "Creates a .rb scenario file that contains the scenario's details" do
		file = subject.create_scenario_file({
			:id => new_scenario['id'],
 			:name => new_scenario['name'],
 			:given => new_scenario['given'],
 			:when => new_scenario['when'],
 			:then => new_scenario['then']
		}, scenario_root)

		require File.join(scenario_root, file)
		scn_ctx = MarsoContext.scenario_context
		scn = scn_ctx.get_scenario.call(new_scenario['id'], {})

		scn.id.must_equal new_scenario['id']
		scn.name.must_equal new_scenario['name']
		given_step = "Given #{new_scenario['given']}"
		when_step = "When #{new_scenario['when']}"
		then_step = "Then #{new_scenario['then']}"
		scn.steps.any? { |s| s.description == given_step }.must_equal true
		scn.steps.any? { |s| s.description == when_step }.must_equal true
		scn.steps.any? { |s| s.description == then_step }.must_equal true
	end

end