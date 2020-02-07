class ExampleJob3 < ApplicationJob
  queue_as :default

  perform_at "October 1st, 2050"

  def perform
    "example job with perform_at"
  end
end
