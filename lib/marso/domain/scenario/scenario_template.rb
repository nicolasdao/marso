require 'marso'

module MarsoContext
	def self.scenario_context(ctx={})
		Marso::ScenarioContext.new({
			:id => "#{id}",
			:before_run => lambda { |id, ctx|
				# Enter the code you want to execute before running the scenario.
				# Uncomment the code below if you want to open a Firefox browser.
				# ctx[:browser] = Marso.openNewBrowser()
			},
			:get_scenario => lambda { |id, ctx|
				Marso::Scenario.new({:id => id, :name => "#{name}"}, ctx)
					.given("#{given}") {
						# TODO: Enter your code here
					}
					.when("#{_when}"){
						# TODO: Enter your code here
					}
					.then("#{_then}"){
						# TODO: Enter your code here
					}
			},
			:after_run => lambda { |id, ctx|
				# Enter the code you want to execute after the scenario is done running.
				# Uncomment the code below if you want to close the Firefox browser.
				# ctx[:browser].close
			}
		}, ctx)
	end
end
