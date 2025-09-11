defmodule RedshiftEcto.Query do
  @moduledoc false
  defstruct [:statement]
end

defimpl DBConnection.Query, for: RedshiftEcto.Query do
  def parse(%RedshiftEcto.Query{} = query, _opts), do: query
  def describe(query, _opts), do: query
  def encode(_query, params, _opts), do: params
  def decode(_query, result, _opts), do: result
end
