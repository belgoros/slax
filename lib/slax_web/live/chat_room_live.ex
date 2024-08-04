defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Repo
  alias Slax.Chat.Room

  def mount(_params, _session, socket) do
    rooms = Repo.all(Room)

    {:ok, assign(socket, hide_topic?: false, rooms: rooms)}
  end

  def handle_params(params, _session, socket) do
    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Repo.get!(Room, id)

        :error ->
          List.first(socket.assigns.rooms)
      end

    {:noreply, assign(socket, hide_topic?: false, room: room)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row">
      <div class="flex flex-col flex-shrink-0 w-64 bg-slate-100">
        <div class="flex items-center justify-between flex-shrink-0 h-16 px-4 border-b border-slate-300">
          <div class="flex flex-col gap-1.5">
            <h1 class="text-lg font-bold text-gray-800">
              Slax
            </h1>
          </div>
        </div>
        <div class="mt-4 overflow-auto">
          <div class="flex items-center h-8 px-3 group">
            <span class="ml-2 text-sm font-medium leading-none">Rooms</span>
          </div>
          <div id="rooms-list">
            <.room_link :for={room <- @rooms} room={room} active={room.id == @room.id} />
          </div>
        </div>
      </div>
      <div class="flex flex-col flex-grow shadow-lg">
        <div class="flex items-center justify-between flex-shrink-0 h-16 px-4 bg-white border-b border-slate-300">
          <div class="flex flex-col gap-1.5">
            <h1 class="text-sm font-bold leading-none">
              #<%= @room.name %>
            </h1>
            <div class="text-xs leading-none h-3.5" phx-click="toggle-topic">
              <%= if @hide_topic? do %>
                <span class="text-slate-600">[Topic hidden]</span>
              <% else %>
                <%= @room.topic %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :active, :boolean, required: true
  attr :room, Room, required: true

  defp room_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center h-8 text-sm pl-8 pr-3",
        (@active && "bg-slate-300") || "hover:bg-slate-300"
      ]}
      patch={~p"/rooms/#{@room}"}
    >
      <.icon name="hero-hashtag" class="w-4 h-4" />
      <span class={["ml-2 leading-none", @active && "font-bold"]}>
        <%= @room.name %>
      </span>
    </.link>
    """
  end

  def handle_event("toggle-topic", _params, socket) do
    {:noreply, update(socket, :hide_topic?, &(!&1))}
  end
end
