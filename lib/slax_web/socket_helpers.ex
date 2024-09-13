defmodule SlaxWeb.SocketHelpers do
  @moduledoc false
  def ok(socket), do: {:ok, socket}

  def noreply(socket), do: {:noreply, socket}

  def reply(socket, data), do: {:reply, data, socket}
end
