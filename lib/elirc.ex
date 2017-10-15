
defmodule Elirc do
  def start do
    Elirc.Parser.start_link
    GenServer.call(Elirc.Parser, {:parse, "test"})
    IO.puts "Hello World"
  end

  def hello, do: start()
end

