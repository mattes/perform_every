class ExampleJob2 < ApplicationJob
  queue_as :default

  perform_every "10 minutes"

  def perform
    "example job with perform_every"
  end
end
