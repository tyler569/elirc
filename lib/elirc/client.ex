
defmodule Elirc.Client do
  use GenServer
  alias Elirc.Parser, as: Parser
  alias Elirc.Permission, as: Permission

  @vsn 0

  @cmd_sigil "~"

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_state) do
    {:ok, sock} = :gen_tcp.connect('irc.openredstone.org', 6667, [:binary])

    {"tbot", "Elixir tbot"} |> fmt_msg(:user) |> ircsend
    "tbot" |> fmt_msg(:nick) |> ircsend

    {:ok, perms} = Permission.start_link(%{"mc:tyler569" => [:admin],
                                           "tyler" => [:admin]})

    {:ok, %{
      sock: sock,
      buf: "",
      perms: perms
    }}
  end

  # == Server Callbacks and Utilities ==
  
  defp append_newline(string) do
    if String.ends_with?(string, "\r\n") do
      string
    else
      string <> "\r\n"
    end
  end

  defp ircsend(:error) do
    nil
  end

  defp ircsend(text) do
    IO.puts "<< " <> text
    GenServer.cast(self(), {:send, text})
  end

  defp fmt_msg({:error, _}, _) do
    :error
  end

  defp fmt_msg({dest, msg}, :privmsg) do
    "PRIVMSG #{dest} :#{msg}"
  end

  defp fmt_msg({usern, realn}, :user) do
    "USER #{usern} 0 * :#{realn}"
  end

  defp fmt_msg(msg, :pong) do
    "PONG :#{msg}"
  end

  defp fmt_msg(channel, :join) do
    "JOIN #{channel}"
  end

  defp fmt_msg(nick, :nick) do
    "NICK #{nick}"
  end

  defp line_action(%{cmd: :ping, trail: t}, _) do
    t |> fmt_msg(:pong) |> ircsend
  end

  defp line_action(%{cmd: :auth}, _) do
    "#openredstone" |> fmt_msg(:join) |> ircsend
    {"NickServ", "identify orepassword"} |> fmt_msg(:privmsg) |> ircsend
  end

  defp line_action(%{cmd: :privmsg, trail: t, from: f}, perms) do
    if f =~ ~r/ORE/ and String.contains?(t, ": ") do
      # Command from Minecraft chat
      [name, msg] = t |> String.split(": ", [parts: 2])

      if msg |> String.starts_with?(@cmd_sigil) do
        # Add mc: to prevent namespace collisions
        handle_command(String.split(msg, " ", [parts: 2]), "mc:" <> name, perms)
        |> fmt_msg(:privmsg)
        |> ircsend
      end
    else
      # Command from IRC chat
      [name | _] = f |> String.split("!", [parts: 2])

      if t |> String.starts_with?(@cmd_sigil) do
        handle_command(String.split(t, " ", [parts: 2]), name, perms)
        |> fmt_msg(:privmsg)
        |> ircsend
      end
    end
  end

  defp line_action(_, _) do
    nil
  end

  defp handle_command(["~echo", msg], name, perms) do
    if Permission.test(perms, name, [:echo, :admin]) do
      {"#openredstone", msg}
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~test" | _], name, perms) do
    if Permission.test(perms, name, [:test, :admin]) do
      {"#openredstone", "Test works!"}
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(_, _, _) do
    {:error, :no_such_command}
  end
  
  def handle_call({:send, text}, _caller, state) do
    :gen_tcp.send(state.sock, text |> append_newline)

    {:reply, :ok, state}
  end

  def handle_cast({:send, text}, state) do
    :gen_tcp.send(state.sock, text |> append_newline)

    {:noreply, state}
  end

  # Handles incoming lines from socket
  def handle_info({:tcp, _pid, data}, state) do

    {buf, lines} = 
      state[:buf] <> data 
      |> String.split("\r\n")
      |> List.pop_at(-1)

    lines
    |> Enum.map(&Parser.strip_colors/1)
    |> Enum.map(fn l -> IO.puts ">> " <> l; l end)
    |> Enum.map(&Parser.parse/1)
    # |> IO.inspect # To inspect the parsed lines mid-flight
    |> Enum.each(&line_action(&1, state.perms))

    {:noreply, Map.put(state, :buf, buf)}
  end

  def handle_info({:tcp_closed, _pid}, _state) do
    IO.puts "Our socket was closed, I must now fall over"
    {:stop, :normal, %{}}
  end
end

