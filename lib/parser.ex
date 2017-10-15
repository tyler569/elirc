
defmodule Elirc.Parser do

  use GenServer

  @regex ~r"^(?::(?<sender>\S+) *)?(?<command>\S+) *(?<attributes>[^:]*):?(?<trail>.*)?$"
  
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_call({:parse, msg}, _caller, state) do
    {:reply, {:ok, parse(msg)}, state}
  end

  def parse(message) do
    parsed = Regex.named_captures(@regex, message)
    
    attrs = parsed["attributes"] |> String.split 
    cmd = case parsed["command"] do
      "PING" -> :ping
      "PONG" -> :pong
      "PRIVMSG" -> :message
      "001" -> :auth
      _ -> {:other, parsed["command"]}
    end
    
    {cmd, parsed["sender"], attrs, parsed["trail"]}
  end
end

