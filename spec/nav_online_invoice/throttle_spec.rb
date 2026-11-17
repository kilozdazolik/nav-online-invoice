# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Throttle do
  let(:now) { [100.0] }
  let(:sleeps) { [] }
  let(:throttle) do
    described_class.new(interval: 1.0, clock: -> { now.first },
                        sleeper: lambda { |seconds|
                          sleeps << seconds
                          now[0] += seconds
                        })
  end

  it "does not wait before the first request" do
    throttle.wait

    expect(sleeps).to be_empty
  end

  it "waits for the rest of the interval" do
    throttle.wait
    now[0] += 0.3
    throttle.wait

    expect(sleeps).to contain_exactly(be_within(1e-9).of(0.7))
  end

  it "does not wait when the interval has passed" do
    throttle.wait
    now[0] += 1.5
    throttle.wait

    expect(sleeps).to be_empty
  end

  it "keeps the interval between calls from several threads" do
    real = described_class.new(interval: 0.05)
    times = []
    Array.new(3) { Thread.new { real.wait.then { times << Process.clock_gettime(Process::CLOCK_MONOTONIC) } } }
         .each(&:join)

    gaps = times.sort.each_cons(2).map { |a, b| b - a }
    expect(gaps).to all(be >= 0.045)
  end

  it "shares one default instance" do
    first = described_class.default

    expect(described_class.default).to be(first)
  end
end
