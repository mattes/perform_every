module PerformEvery
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "tasks/perform_every_tasks.rake"
    end
  end
end
