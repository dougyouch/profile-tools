# frozen_string_literal: true

require_relative 'lib/profile_tools/version'

Gem::Specification.new do |s|
  s.name        = 'profile-tools'
  s.version     = ProfileTools::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Count the objects, time and GC runs of chosen methods, set from a YAML file'
  s.description = 'List the methods to watch in a YAML file, restart, and ProfileTools logs, per request, how many ' \
                  'times each was called, how long it took, how many objects it allocated and how many garbage ' \
                  'collections ran inside it. Methods are wrapped at boot without changing their code, so it can ' \
                  'be turned on for a production box and removed again. Built for finding the code that creates ' \
                  'the most objects and causes the most garbage collection.'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/profile-tools'
  s.files       = Dir['lib/**/*.rb', 'README.md', 'UPGRADING.md', 'LICENSE', 'CHANGELOG.md']
  s.required_ruby_version = '>= 3.4'

  s.add_dependency 'activesupport', '>= 7.1'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri'] = 'https://github.com/dougyouch/profile-tools'
  s.metadata['changelog_uri'] = 'https://github.com/dougyouch/profile-tools/blob/master/CHANGELOG.md'
  s.metadata['bug_tracker_uri'] = 'https://github.com/dougyouch/profile-tools/issues'
  s.metadata['documentation_uri'] = 'https://rubydoc.info/gems/profile-tools'
end
