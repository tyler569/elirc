
defmodule Elirc.Parser do

  @vsn 0

  @irc_line ~r"^(?::(?<sender>\S+) *)?(?<command>\S+) *(?<attributes>[^:]*):?(?<trail>.*)?$"
  
  def parse(message) do
    parsed = Regex.named_captures(@irc_line, message)
    
    attrs = parsed["attributes"] |> String.split 

    cmd = case parsed["command"] |> String.upcase do
      "PING" -> :ping
      "PONG" -> :pong
      "PRIVMSG" -> :privmsg
      "001" -> :auth
      _ -> {:other, parsed["command"]}
    end

    %{
      cmd: cmd,
      from: parsed["sender"],
      attrs: attrs,
      trail: parsed["trail"]
    }
  end

  def strip_colors(string) do
    string
    |> String.replace(~r"\x03..(?:,..)?", "")
    |> String.replace(["\x02", "\x1D", "\x1F", "\x16", "\x0F"], "")
  end

end

