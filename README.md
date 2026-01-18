# WhatIsMyIp

Fetches your external IP address by racing 24 public services in parallel. Returns as soon as you have the confidence you need.

## Installation

```elixir
def deps do
  [{:what_is_my_ip, github: "/chgeuer/what_is_my_ip"}]
end
```

## Usage

```elixir
# Get 3 confirmations (default)
WhatIsMyIp.fetch()
#=> {:ok, [{"203.0.113.42", ["https://wtfismyip.com/text", "https://myip.wtf/text", "http://ip-api.com/json"]}]}

# Just need one fast answer
WhatIsMyIp.fetch(1)
#=> {:ok, [{"203.0.113.42", ["https://wtfismyip.com/text"]}]}

# Maximum confidence - wait for all services
WhatIsMyIp.fetch(:all)
#=> {:ok, [{"203.0.113.42", ["https://wtfismyip.com/text", "https://myip.wtf/text", ...]}]}

# Custom timeout
WhatIsMyIp.fetch(5, timeout: to_timeout(second: 10))

# Bang variant
WhatIsMyIp.fetch!(1)
#=> [{"203.0.113.42", ["https://wtfismyip.com/text"]}]
```

## Response Format

Results are grouped by IP address. If all services agree, you get a single-element list:

```elixir
[{"203.0.113.42", ["https://service1.com/", "https://service2.com/", ...]}]
```

If services disagree (rare, possibly indicating network issues), you'll see multiple entries:

```elixir
[{"203.0.113.42", ["https://service1.com/"]}, {"198.51.100.1", ["https://service2.com/"]}]
```

## Features

- **Fast** — Services ordered by response time; fastest responders first
- **Resilient** — 24 services, TLS everywhere possible, graceful timeout handling  
- **Parallel** — All requests fire simultaneously
- **Flexible** — Choose your confidence level: 1 response, 3, 5, or all

## License

MIT

