# Sidekiq::Sorbet

Add typed arguments to your Sidekiq Workers.

## Quick Example

```ruby
# Worker Class
class AnalyzeAttachmentWorker
  include Sidekiq::Job
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :attachment_id, Integer
    const :regenerate, T::Boolean, default: false
  end

  def run
    attachment = Attachment.find(attachment_id)       # attachment_id is typed here
    return if attachment.analyzed? && !regenerate     # regenerate is type here too

    attachment.analyze!
  end
end

# Call Worker
AnalyzeAttachmentWorker.run_async(attachment_id: 1)                     # arguments are typed and validated here
AnalyzeAttachmentWorker.run_sync(attachment_id: 1, regenerate: true)    # arguments are typed and validated here too
```

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add sidekiq-sorbet
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install sidekiq-sorbet
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sidekiq-sorbet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/sidekiq-sorbet/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sidekiq::Sorbet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/sidekiq-sorbet/blob/main/CODE_OF_CONDUCT.md).
