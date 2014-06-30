require 'marso'

module MarsoContext
  def self.story(ctx={})
    Marso::Story.new({
      :id => "#{id}",
      :name => "#{name}",
      :in_order_to => "#{in_order_to}",
      :as_a => "#{as_a}",
      :i => "#{i}"
    },
    ctx)
  end
end