
defmodule Elirc do

  def start(_x, _y) do
    # children = [
    #   %{
    #     id: Elirc.Client,
    #     start: {Elirc.Client.start_link, []}
    #   }
    # ]

    # Supervisor.start_link(children, strategy: :one_for_one)
    Elirc.Client.start_link
  end
  
end

