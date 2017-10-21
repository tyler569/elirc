
defmodule Elirc.Formatter do

  def fmt_msg(msgs) when is_list(msgs) do
    fmt_msgs = msgs |> Enum.map(&fmt_msg/1)

    if Enum.any?(fmt_msgs, &is_tuple/1) do
      {:error, fmt_msgs}
    else
      fmt_msgs |> Enum.join
    end
  end
  
  def fmt_msg({:user, usern, realn}) do
    "USER #{usern} 0 * :#{realn}\r\n"
  end

  def fmt_msg({:nick, nick}) do
    "NICK #{nick}\r\n"
  end

  def fmt_msg({:pong, msg}) do
    "PONG :#{msg}\r\n"
  end

  def fmt_msg({:join, channel}) do
    "JOIN #{channel}\r\n"
  end

  def fmt_msg({:privmsg, dest, msg}) do
    "PRIVMSG #{dest} :#{msg}\r\n"
  end

  def fmt_msg(_) do
    {:error, :no_such_formatter}
  end

end
