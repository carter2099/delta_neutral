require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[rubocop test]
