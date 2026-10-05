# frozen_string_literal: true

require 'spec_helper'

describe 'profile-tools.gemspec' do
  let(:spec) { Gem::Specification.load(File.expand_path('../profile-tools.gemspec', __dir__)) }

  it 'packages only the library and user-facing docs' do
    expect(spec.files.reject { |file| file.start_with?('lib/') }).to contain_exactly(
      'CHANGELOG.md', 'LICENSE', 'README.md', 'UPGRADING.md'
    )
  end

  it 'requires activesupport 7.1 or newer' do
    dependency = spec.runtime_dependencies.find { |dep| dep.name == 'activesupport' }
    expect(dependency.requirement).not_to be_satisfied_by(Gem::Version.new('7.0.8'))
    expect(dependency.requirement).to be_satisfied_by(Gem::Version.new('7.1.0'))
    expect(dependency.requirement).to be_satisfied_by(Gem::Version.new('8.1.4'))
  end

  it 'links to the source, changelog, issues and api docs' do
    expect(spec.metadata).to include(
      'source_code_uri' => 'https://github.com/dougyouch/profile-tools',
      'changelog_uri' => 'https://github.com/dougyouch/profile-tools/blob/master/CHANGELOG.md',
      'bug_tracker_uri' => 'https://github.com/dougyouch/profile-tools/issues',
      'documentation_uri' => 'https://rubydoc.info/gems/profile-tools'
    )
  end
end
