defmodule RedshiftEcto.DataConnection do
  @moduledoc false
  use DBConnection

  alias AWS.RedshiftData
  alias RedshiftEcto.{Query, Result}

  defstruct [:client, :database, :cluster_identifier, :secret_arn, :workgroup_name]

  @impl true
  def init(opts) do
    client_opts =
      Keyword.take(opts, [:access_key_id, :secret_access_key, :region, :scheme, :host, :port])

    client = AWS.Client.create(client_opts)

    state = %__MODULE__{
      client: client,
      database: Keyword.fetch!(opts, :database),
      cluster_identifier: opts[:cluster_identifier],
      secret_arn: opts[:secret_arn],
      workgroup_name: opts[:workgroup_name]
    }

    {:ok, state}
  end

  @impl true
  def handle_prepare(%Query{} = query, _opts, state) do
    {:ok, query, state}
  end

  @impl true
  def handle_execute(%Query{statement: statement} = query, params, _opts, state) do
    with {:ok, %{id: id}} <-
           RedshiftData.execute_statement(state.client, request(statement, params, state)),
         {:ok, result} <- RedshiftData.get_statement_result(state.client, id: id) do
      {:ok, query, to_result(result), state}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  defp request(sql, params, state) do
    base = %{sql: sql, database: state.database}
    base = maybe_put(base, :cluster_identifier, state.cluster_identifier)
    base = maybe_put(base, :secret_arn, state.secret_arn)
    base = maybe_put(base, :workgroup_name, state.workgroup_name)

    if params == [] do
      base
    else
      Map.put(base, :parameters, encode_params(params))
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_params(params) do
    Enum.with_index(params, 1)
    |> Enum.map(fn {value, idx} ->
      %{name: "p#{idx}", value: encode_param(value)}
    end)
  end

  defp encode_param(nil), do: %{is_null: true}
  defp encode_param(v) when is_integer(v), do: %{long_value: v}
  defp encode_param(v) when is_float(v), do: %{double_value: v}
  defp encode_param(v) when is_boolean(v), do: %{boolean_value: v}
  defp encode_param(v), do: %{string_value: to_string(v)}

  defp to_result(result) do
    columns = Enum.map(result.column_metadata, & &1.name)

    rows =
      Enum.map(result.records, fn record ->
        Enum.map(record, &decode_field/1)
      end)

    %Result{columns: columns, rows: rows, num_rows: length(rows)}
  end

  defp decode_field(%{string_value: v}), do: v
  defp decode_field(%{long_value: v}), do: v
  defp decode_field(%{double_value: v}), do: v
  defp decode_field(%{boolean_value: v}), do: v
  defp decode_field(%{is_null: true}), do: nil
  defp decode_field(_), do: nil
end
