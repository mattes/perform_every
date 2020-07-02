class ExampleJob1 < ApplicationJob
  queue_as :default

  def perform
    "example job without perform_every and perform_at"
  end
end
