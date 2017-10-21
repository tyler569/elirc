
defmodule Elirc.Permission do
  use Agent

  def start_link(init) do
    Agent.start_link(fn -> init end)
  end

  def test(bucket, name, [v | vs]) do
    case test(bucket, name, v) do
      true -> true
      false -> test(bucket, name, vs)
    end
  end

  def test(_, _, []) do
    false
  end

  def test(bucket, name, value) do
    value in (get(bucket, name) || []) 
  end

  def push(bucket, name, value) do
    put(bucket, name, [value | get(bucket, name) || []])
  end

  def pop(bucket, name, value) do
    put(bucket, name, List.delete(get(bucket, name) || [], value))
  end

  def dump(bucket) do
    Agent.get(bucket, fn x -> x end)
  end

  defp get(bucket, key) do
    Agent.get(bucket, &Map.get(&1, key))
  end

  defp put(bucket, key, value) do
    Agent.update(bucket, &Map.put(&1, key, value))
  end

end

