require 'marso'

module MarsoContext
  def self.feature(ctx={})
    Marso::Feature.new({
      :id => "#{id}",
      :name => "#{name}",
      :in_order_to => "#{in_order_to}",
      :as_a => "#{as_a}",
      :i => "#{i}"
    })
  end
end