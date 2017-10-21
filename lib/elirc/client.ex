
defmodule Elirc.Client do
  use GenServer

  alias Elirc.Formatter, as: Formatter
  alias Elirc.Parser, as: Parser
  alias Elirc.Permission, as: Permission

  @vsn 0

  @cmd_sigil "~"

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_state) do
    {:ok, sock} = :gen_tcp.connect('irc.openredstone.org', 6667, [:binary])

    [{:user, "tbot", "Elixir tbot"},
     {:nick, "tbot"}] 
    |> Formatter.fmt_msg
    |> (fn msg -> :gen_tcp.send(sock, msg) end).()

    {:ok, perms} = Permission.start_link(%{
      "mc:tyler569" => [:admin],
      "mc:LordDecapo" => [:admin],
      "tyler" => [:admin]
    })

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

  defp line_action(%{cmd: :ping, trail: t}, _) do
    {:pong, t}
  end

  defp line_action(%{cmd: :auth}, _) do
    [{:join, "#openredstone"},
     {:privmsg, "NickServ", "identify orepassword"}]
  end

  defp line_action(%{cmd: :privmsg, trail: t, from: f}, perms) do
    if f =~ ~r/ORE/ and String.contains?(t, ": ") do
      # Command from Minecraft chat
      [name, msg] = t |> String.split(": ", [parts: 2])

      if msg |> String.starts_with?(@cmd_sigil) do
        # Add mc: to prevent namespace collisions
        handle_command(String.split(msg, " ", [parts: 2]), "mc:" <> name, perms)
      else
        {:noerror, :no_command}
      end
    else
      # Command from IRC chat
      [name | _] = f |> String.split("!", [parts: 2])

      if t |> String.starts_with?(@cmd_sigil) do
        handle_command(String.split(t, " ", [parts: 2]), name, perms)
      else
        {:noerror, :no_command}
      end
    end
  end

  defp line_action(_, _) do
    {:noerror, :unknown}
  end

  defp handle_command(["~echo", msg], name, perms) do
    if Permission.test(perms, name, [:echo, :admin]) do
      {:privmsg, "#openredstone", String.replace(msg, "/", "./")}
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~test" | _], name, perms) do
    if Permission.test(perms, name, [:test, :admin]) do
      {:privmsg, "#openredstone", "Test works!"}
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~auth", params], name, perms) do
    if Permission.test(perms, name, :admin) do
      try do
        [to, perm] = String.split(params)
        Permission.push(perms, to, String.to_existing_atom(perm))
        {:privmsg, "#openredstone", "#{to} authorized for #{perm}"}
      rescue
        MatchError -> {:error, :bad_format}
        ArgumentError -> {:error, :no_such_permission}
      end
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~deauth", params], name, perms) do
    if Permission.test(perms, name, :admin) do
      try do
        [to, perm] = String.split(params)
        Permission.pop(perms, to, String.to_existing_atom(perm))
        {:privmsg, "#openredstone", "#{to} deauthorized for #{perm}"}
      rescue
        MatchError -> {:error, :bad_format}
        ArgumentError -> {:error, :no_such_permission}
      end
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~perms" | params], name, perms) do
    if Permission.test(perms, name, [:admin, :perms]) do
      if params == [] do
        {:privmsg, "#openredstone", inspect(Permission.dump(perms))}
      else
        {:privmsg, "#openredstone", inspect(Map.get(Permission.dump(perms), hd params))}
      end
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(["~tryign" | _], name, perms) do
    if Permission.test(perms, name, [:tryign, :admin]) do
      {:privmsg, "#openredstone", "Try IGN!"}
    else
      {:error, :no_permission}
    end
  end

  defp handle_command(_, _, _) do
    {:error, :no_such_command}
  end

  defp filter_error(line, err_msg) do
    case line do
      {:error, message} ->
        IO.puts("!! " <> err_msg <> ": " <> to_string(message))
        false
      {:noerror, _} -> false
      _ -> true
    end
  end
  
  def handle_call({:send, text}, _caller, state) do
    :gen_tcp.send(state.sock, text |> append_newline)

    {:reply, :ok, state}
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
    |> Enum.map(&line_action(&1, state.perms))
    |> Enum.filter(&filter_error(&1, "Handle error"))
    |> Enum.map(&Formatter.fmt_msg/1)
    |> Enum.filter(&filter_error(&1, "Format error"))
    |> Enum.map(fn l -> IO.puts "<< " <> String.trim(l); l end)
    |> Enum.each(&:gen_tcp.send(state.sock, &1))

    {:noreply, Map.put(state, :buf, buf)}
  end

  def handle_info({:tcp_closed, _pid}, _state) do
    IO.puts "!! Our socket was closed, I must now fall over"
    {:stop, :normal, %{}}
  end
end

