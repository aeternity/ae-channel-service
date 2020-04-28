defmodule ContractHelper do
  def to_sophia_bytes(binary) when is_binary(binary) do
    "#" <> Base.encode16(binary)
  end

  def add_quotes(b) when is_binary(b), do: <<"\"", b::binary, "\"">>
  def add_quotes(str) when is_list(str), do: "\"" ++ str ++ "\""
end
