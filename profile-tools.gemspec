# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'profile-tools'
  s.version     = '0.1.0'
  s.licenses    = ['MIT']
  s.summary     = 'Profile tools'
  s.description = 'Dynamically add method profiling to any class.  Collects method times and objects created.'
  s.authors     = ['Doug Youch']
  s.email       = 'dougyouch@gmail.com'
  s.homepage    = 'https://github.com/dougyouch/profile-tools'
  s.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|examples)/}) }
end
