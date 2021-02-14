# frozen_string_literal: true

require "rails/engine"

module ActiveEventStore
  class Engine < ::Rails::Engine
    config.active_event_store = ActiveEventStore.config

    # Use before configuration hook to check for ActiveJob presence
    ActiveSupport.on_load(:before_configuration) do
      next warn "Active Job is not loaded. Active Event Store asynchrounous subscriptions won't worke" unless defined?(::ActiveJob)

      require "active_event_store/subscriber_job"
      require "active_event_store/rspec/have_enqueued_async_subscriber_for" if defined?(::RSpec::Matchers)
    end

    config.to_prepare do
      ActiveEventStore.reset_event_store!
      ActiveSupport.run_load_hooks(:active_event_store, ActiveEventStore)
    end
  end

  class << self
    def reset_event_store!
      ActiveEventStore.event_store = ActiveEventStore.new_event_store
    end

    def new_event_store
      # See https://railseventstore.org/docs/subscribe/#scheduling-async-handlers-after-commit
      RailsEventStore::Client.new(
        dispatcher: RubyEventStore::ComposedDispatcher.new(
          RailsEventStore::AfterCommitAsyncDispatcher.new(scheduler: RailsEventStore::ActiveJobScheduler.new),
          RubyEventStore::Dispatcher.new
        ),
        repository: ActiveEventStore.config.repository,
        mapper: ActiveEventStore::Mapper.new(mapping: ActiveEventStore.mapping),
        **ActiveEventStore.config.store_options
      )
    end
  end
end
