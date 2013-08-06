require "bundler/gem_tasks"
require "yard"

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/*/*.rb']
end

desc "Uninstalls the gem"
task :uninstall do
  system "gem uninstall win32-loquendo"
end
