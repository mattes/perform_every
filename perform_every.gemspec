$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "perform_every/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name = "perform_every"
  spec.version = PerformEvery::VERSION
  spec.authors = ["Matthias Kadenbach"]
  spec.email = ["matthias.kadenbach@gmail.com"]
  spec.homepage = "https://github.com/mattes/perform_every"
  spec.summary = "Cron for ActiveJob"
  spec.description = "Runs jobs at specified intervals."
  spec.license = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.0.2", ">= 6.0.2.1"
  spec.add_dependency "fugit", "~> 1.1"
  spec.add_dependency "with_advisory_lock", "~> 3.2"

  spec.add_development_dependency "pg", "~> 1.2.2"
  spec.add_development_dependency "byebug", "~> 11.1", ">= 11.1.1"
end
