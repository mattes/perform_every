class ExampleJob7 < ApplicationJob
  queue_as :default

  perform_every "10 minutes"
  perform_at "October 1st, 2050"

  def perform(var)
    "example job with a variable: #{var}"
  end
end
