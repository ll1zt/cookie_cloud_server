defmodule CookieCloudServer.Plugs.RateLimit.Sweeper do
  @moduledoc """
  Owns the rate-limit ETS table and periodically deletes finished windows so
  the table stays bounded on long-running deployments.
  """

  use GenServer

  @table :cookie_cloud_rate_limit

  @doc "Start the sweeper that creates the ETS table and schedules cleanup."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    create_table()

    sweep_interval_ms =
      Application.get_env(
        :cookie_cloud_server,
        :rate_limit_sweep_interval_ms,
        window_ms()
      )

    schedule_sweep(sweep_interval_ms)

    {:ok, %{sweep_interval_ms: sweep_interval_ms}}
  end

  @impl true
  def handle_info(:sweep, %{sweep_interval_ms: interval} = state) do
    sweep_expired()
    schedule_sweep(interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @doc """
  Delete counters from finished windows. Returns the number of deleted keys.
  Public for testing.
  """
  def sweep_expired do
    current_window = div(System.system_time(:millisecond), window_ms())

    :ets.select_delete(@table, [
      {{{:_, :"$1"}, :_}, [{:<, :"$1", current_window}], [true]}
    ])
  end

  defp window_ms,
    do: Application.get_env(:cookie_cloud_server, :rate_limit_window_ms, 15 * 60 * 1000)

  defp schedule_sweep(interval_ms), do: Process.send_after(self(), :sweep, interval_ms)

  defp create_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        @table
    end
  end
end
