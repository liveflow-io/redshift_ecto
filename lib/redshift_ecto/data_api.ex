defmodule RedshiftEcto.DataAPI do
  @moduledoc """
  Thin wrapper around `AWS.RedshiftData` used by the adapter to run SQL
  statements through the Redshift Data API. The module provides a synchronous
  interface that executes a statement and waits for the result before
  returning.
  """

  use DBConnection

  alias AWS.RedshiftData
  alias RedshiftEcto.Query

  # Client API --------------------------------------------------------------

  @doc """
  Start a DBConnection process for the Data API.
  """
  def start_link(opts) do
    DBConnection.start_link(__MODULE__, opts)
  end

  @doc """
  Execute `sql` with the given `params` using the connection.
  """
  def execute(conn, sql, params, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)
    query = %Query{statement: sql}
    DBConnection.execute(conn, query, params, timeout: timeout)
  end

  # DBConnection callbacks --------------------------------------------------

  @impl true
  def connect(opts) do
    client_opts =
      opts
      |> Keyword.take([:access_key_id, :secret_access_key, :region, :endpoint])

    {:ok, %{client: AWS.Client.create(client_opts), opts: opts}}
  end

  @impl true
  def handle_execute(%Query{statement: sql} = query, params, _opts, state) do
    sql = interpolate(sql, params)

    request =
      state.opts
      |> Keyword.take([:cluster_identifier, :database, :db_user, :secret_arn, :workgroup_name])
      |> Map.new()
      |> Map.put(:sql, sql)

    case RedshiftData.execute_statement(state.client, request) do
      {:ok, %{body: %{"Id" => id}}} ->
        case await_result(state.client, id) do
          {:ok, result} -> {:ok, query, result, state}
          {:error, reason} -> {:error, reason, state}
        end

      {:error, reason} ->
        {:error, reason, state}
    end
  end

  @impl true
  def disconnect(_err, _state), do: :ok

  @impl true
  def handle_prepare(%Query{} = query, _opts, state) do
    {:ok, query, state}
  end

  @impl true
  def handle_close(_query, _opts, state) do
    {:ok, nil, state}
  end

  # Internal helpers -------------------------------------------------------

  defp await_result(client, id) do
    Stream.repeatedly(fn -> :ok end)
    |> Enum.reduce_while(nil, fn _, _ ->
      case RedshiftData.describe_statement(client, %{id: id}) do
        {:ok, %{body: %{"Status" => "FINISHED"}}} ->
          {:halt, fetch_result(client, id)}

        {:ok, %{body: %{"Status" => status}}} when status in ["STARTED", "SUBMITTED", "PICKED"] ->
          Process.sleep(200)
          {:cont, nil}

        {:ok, %{body: %{"Error" => error}}} ->
          {:halt, {:error, error}}

        other ->
          {:halt, {:error, other}}
      end
    end)
  end

  defp fetch_result(client, id) do
    case RedshiftData.get_statement_result(client, %{id: id}) do
      {:ok, %{body: body}} ->
        columns = Enum.map(body["ColumnMetadata"], & &1["name"])

        rows =
          Enum.map(body["Records"], fn record ->
            Enum.map(record, &value_from_field/1)
          end)

        result = %DBConnection.Result{columns: columns, rows: rows, num_rows: length(rows)}
        {:ok, result}

      other ->
        {:error, other}
    end
  end

  defp value_from_field(%{"longValue" => v}), do: v
  defp value_from_field(%{"doubleValue" => v}), do: v
  defp value_from_field(%{"stringValue" => v}), do: v
  defp value_from_field(%{"booleanValue" => v}), do: v
  defp value_from_field(_), do: nil

  defp interpolate(sql, params) do
    Enum.with_index(params, 1)
    |> Enum.reduce(sql, fn {value, idx}, acc ->
      placeholder = "$#{idx}"
      String.replace(acc, placeholder, quote_value(value))
    end)
  end

  defp quote_value(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "''") <> "'"
  end

  defp quote_value(value) when is_integer(value) or is_float(value) do
    to_string(value)
  end

  defp quote_value(true), do: "true"
  defp quote_value(false), do: "false"
  defp quote_value(nil), do: "null"
  defp quote_value(other), do: "'" <> to_string(other) <> "'"
end
