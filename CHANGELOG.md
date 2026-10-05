# Changelog

## [0.2.0](https://github.com/dougyouch/profile-tools/compare/v0.1.0...v0.2.0) (2026-10-05)


### ⚠ BREAKING CHANGES

* ProfileTools is now a module. Use ProfileTools.profile_method('User#save') and ProfileTools.stop_profiling('User.find', ...) instead of the profile_*/remove_profiled_* instance methods. Per-type count_objects is replaced by an exact allocations total plus gc_count and gc_time, the collector exposes stats (MethodStats objects) instead of methods (hashes), and the log format changed. See UPGRADING.md.
* **gem:** Ruby 3.4 or newer and ActiveSupport 7.1 or newer are now required. Ruby 3.4 is the first version where forwarding arguments with ... allocates nothing, which exact allocation counts depend on.

### Features

* count allocations exactly and profile from a yaml file with no code changes ([d9a2fb3](https://github.com/dougyouch/profile-tools/commit/d9a2fb3acc3cd487c0004b60ad526ca220076983))


### Build System

* **gem:** require ruby 3.4 and activesupport 7.1 ([2347ecf](https://github.com/dougyouch/profile-tools/commit/2347ecfea681cde5ca70ddf440015acb5090dcfb))

## 0.1.0 (2019-08-30)

* Initial release: profile methods listed in a YAML file, logging call counts, time and object counts per method
