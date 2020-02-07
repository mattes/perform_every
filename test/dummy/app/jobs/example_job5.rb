class ExampleJob5 < ApplicationJob
  queue_as :default

  perform_every "10 minutes"
  perform_every "3 days"
  perform_at "October 1st, 2050"
  perform_at "October 2st, 2050"

  def perform
    "example job with multiple perform_every and perform_at"
  end
end
