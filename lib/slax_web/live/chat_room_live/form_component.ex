defmodule SlaxWeb.ChatRoomLive.FormComponent do
  use SlaxWeb, :live_component

  alias Slax.Chat
  alias Slax.Chat.Room

  import SlaxWeb.RoomComponents

  def render(assigns) do
    ~H"""
    <div id="new-room-form">
      <.room_form form={@form} />
    </div>
    """
  end

  def mount(socket) do
    changeset = Chat.change_room(%Room{})

    socket
    |> assign_form(changeset)
    |> ok()
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
