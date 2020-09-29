class ExampleJob6 < ApplicationJob
  queue_as :default

  perform_every "10 minutes"
  perform_at "October 1st, 2050"

  def perform(var = "default")
    "example job with a default variable: #{var}"
  end
end
