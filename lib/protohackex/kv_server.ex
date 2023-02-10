defmodule Protohackex.KvServer do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  # Callbacks

  @impl GenServer
  def init(args) do
    port = Keyword.fetch!(args, :port)
    {:ok, _socket} = :gen_udp.open(port, [:binary, {:active, true}])
    {:ok, new_db()}
  end

  @impl GenServer

  def handle_info({:udp, socket, ip, in_port_no, _anc_date, packet}, db) do
    handle_info({:udp, socket, ip, in_port_no, packet}, db)
  end

  def handle_info({:udp, socket, ip, in_port_no, packet}, db) when byte_size(packet) < 1000 do
    db =
      case parse_message(packet) do
        :version ->
          send_message(
            socket,
            ip,
            in_port_no,
            "version",
            "Ken's Key-Value Store 1.0-final-beta-0.24.389.42"
          )

          db

        {:insert, key, value} ->
          Logger.info("Insert: #{key} = #{value}")
          insert(db, key, value)

        {:retrieve, key} ->
          Logger.info("Query: #{key}")
          value = query(db, key)
          send_message(socket, ip, in_port_no, key, value)
          db
      end

    {:noreply, db}
  end

  def handle_info(message, db) do
    Logger.warn("Unexpected message: #{inspect(message)}")
    {:noreply, db}
  end

  defp parse_message(packet) do
    cond do
      # The version command should not be interpreted as a key so it must be parsed
      # before other commands.
      packet == "version" ->
        :version

      String.contains?(packet, "=") ->
        [key, value] = String.split(packet, "=", parts: 2)
        {:insert, key, value}

      true ->
        {:retrieve, packet}
    end
  end

  defp send_message(socket, ip, in_port_no, key, value) do
    message = "#{key}=#{value}"

    if byte_size(message) < 1000 do
      :ok = :gen_udp.send(socket, ip, in_port_no, "#{key}=#{value}")
    else
      Logger.warn("Response too large: #{inspect(message)}")
    end
  end

  # Database functions
  # The "database" is a map and has only 2 operations so no point
  # abstracting this.

  defp new_db(), do: %{}

  defp insert(db, "version", _value) do
    db
  end

  defp insert(db, key, value) do
    Map.put(db, key, value)
  end

  defp query(db, key) do
    Map.get(db, key, "")
  end
end
