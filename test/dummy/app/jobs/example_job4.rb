class ExampleJob4 < ApplicationJob
  queue_as :default

  perform_every "10 minutes"
  perform_at "October 1st, 2050"

  def perform
    "example job with perform_every and perform_at"
  end
end
