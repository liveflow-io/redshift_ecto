defmodule RedshiftEcto.Query do
  @moduledoc false
  @behaviour DBConnection.Query

  defstruct [:statement]

  @impl true
  def parse(%__MODULE__{} = query, _opts), do: query

  @impl true
  def describe(query, _opts), do: query

  @impl true
  def encode(_query, params, _opts), do: {:ok, params}

  @impl true
  def decode(_query, result, _opts), do: {:ok, result}

  @impl true
  def close(_query, _opts), do: :ok
end
