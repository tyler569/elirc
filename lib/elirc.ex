
defmodule Elirc do

  @vsn 0

  def main(_) do
    start()
  end

  def start do
    Elirc.Client.start_link     
  end

end

