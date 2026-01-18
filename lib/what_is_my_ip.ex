defmodule WhatIsMyIp do
  @moduledoc """
  Fetches your external IP address by querying multiple public services in parallel.
  """

  @type ip_result :: {ip :: String.t(), sources :: [String.t()]}

  @services [
    # Sorted by response time (benchmarked 2026-01-18)
    {"https://wtfismyip.com/text", :raw},
    {"https://myip.wtf/text", :raw},
    {"http://ip-api.com/json", {:json, "query"}},
    {"https://ident.me/", :raw},
    {"https://ipwhois.app/json/", {:json, "ip"}},
    {"https://checkip.amazonaws.com/", :raw},
    {"https://l2.io/ip", :raw},
    {"https://ip.tyk.nu/", :raw},
    {"https://whatismyip.akamai.com/", :raw},
    {"https://icanhazip.com/", :raw},
    {"https://ipinfo.io/json", {:json, "ip"}},
    {"https://eth0.me/", :raw},
    {"https://ipecho.net/plain", :raw},
    {"https://myexternalip.com/raw", :raw},
    {"https://ifconfig.me/ip", :raw},
    {"https://ipinfo.io/ip", :raw},
    {"https://trackip.net/ip", :raw},
    {"https://ifconfig.co/ip", :raw},
    {"https://ipapi.co/ip", :raw},
    {"https://httpbin.org/ip", {:json, "origin"}},
    {"https://api.ipify.org?format=json", {:json, "ip"}},
    {"https://json.geoiplookup.io/", {:json, "ip"}},
    {"https://ip.qaros.com/", :raw},
    {"https://curlmyip.net/", :raw}
  ]

  @opts_schema NimbleOptions.new!(
                 timeout: [
                   type: :timeout,
                   default: to_timeout(second: 2),
                   doc: "Timeout per service request."
                 ]
               )

  @doc """
  Fetches your external IP address from multiple services in parallel.

  ## Arguments

    * `responses` - `:all` or positive integer (default: `3`)
    * `opts` - keyword list of options

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Examples

      WhatIsMyIp.fetch()
      WhatIsMyIp.fetch(1)
      WhatIsMyIp.fetch(:all)
      WhatIsMyIp.fetch(timeout: to_timeout(second: 5))
      WhatIsMyIp.fetch(:all, timeout: to_timeout(second: 5))
      WhatIsMyIp.fetch(3, timeout: to_timeout(second: 5))
  """
  @spec fetch(:all | pos_integer(), keyword()) :: {:ok, [ip_result()]} | {:error, term()}
  def fetch(responses \\ 3, opts \\ [])

  def fetch(opts, []) when is_list(opts), do: fetch(3, opts)

  def fetch(:all, opts) do
    timeout = validated_timeout(opts)

    results =
      @services
      |> Task.async_stream(&fetch_one(&1, timeout), timeout: timeout, on_timeout: :kill_task)
      |> Enum.flat_map(fn
        {:ok, {:ok, result}} -> [result]
        _other -> []
      end)
      |> group_by_ip()

    {:ok, results}
  end

  def fetch(n, opts) when is_integer(n) and n > 0 do
    timeout = validated_timeout(opts)
    parent = self()
    ref = make_ref()

    tasks =
      for service <- @services do
        Task.async(fn ->
          result = fetch_one(service, timeout)
          send(parent, {ref, result})
          result
        end)
      end

    result = await_n(ref, n, length(tasks), timeout, [])
    Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))

    case result do
      {:ok, collected} -> {:ok, group_by_ip(flush_successes(ref, collected))}
      {:error, _} = error -> flush_all(ref) && error
    end
  end

  @doc """
  Same as `fetch/2`, but raises on error.
  """
  @spec fetch!(:all | pos_integer(), keyword()) :: [ip_result()]
  def fetch!(responses \\ 3, opts \\ [])

  def fetch!(opts, []) when is_list(opts), do: fetch!(3, opts)

  def fetch!(responses, opts) do
    case fetch(responses, opts) do
      {:ok, results} -> results
      {:error, reason} -> raise "Failed to fetch IP: #{inspect(reason)}"
    end
  end

  defp validated_timeout(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)
    opts[:timeout]
  end

  defp await_n(_ref, 0, _remaining, _timeout, acc), do: {:ok, acc}
  defp await_n(_ref, _n, 0, _timeout, []), do: {:error, :no_successful_response}
  defp await_n(_ref, _n, 0, _timeout, acc), do: {:ok, acc}

  defp await_n(ref, n, remaining, timeout, acc) do
    receive do
      {^ref, {:ok, result}} -> await_n(ref, n - 1, remaining - 1, timeout, [result | acc])
      {^ref, {:error, _}} -> await_n(ref, n, remaining - 1, timeout, acc)
    after
      timeout -> if acc == [], do: {:error, :timeout}, else: {:ok, acc}
    end
  end

  defp flush_successes(ref, acc) do
    receive do
      {^ref, {:ok, result}} -> flush_successes(ref, [result | acc])
      {^ref, {:error, _}} -> flush_successes(ref, acc)
    after
      0 -> acc
    end
  end

  defp flush_all(ref) do
    receive do
      {^ref, _} -> flush_all(ref)
    after
      0 -> :ok
    end
  end

  defp group_by_ip(results) do
    results
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
    |> Map.to_list()
  end

  defp fetch_one({url, parser}, timeout) do
    case Req.get(url, receive_timeout: timeout, connect_options: [timeout: timeout], retry: false) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, {url, parse(body, parser)}}

      {:ok, %{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, {:exception, e}}
  end

  defp parse(body, :raw) when is_binary(body), do: String.trim(body)
  defp parse(body, {:json, field}) when is_map(body), do: body |> Map.fetch!(field) |> String.trim()
end
