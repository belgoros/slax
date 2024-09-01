defmodule SlaxWeb.ChatRoomLive.Index do
  use SlaxWeb, :live_view

  alias Slax.Chat

  def render(assigns) do
    ~H"""
    <main class="flex-1 max-w-4xl p-6 mx-auto">
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-semibold"><%= @page_title %></h1>
        <button
          phx-click={show_modal("new-room-modal")}
          class="px-4 py-2 font-semibold bg-white border rounded shadow-sm border-slate-400"
        >
          Create room
        </button>
      </div>
      <div class="border rounded bg-slate-50">
        <div id="rooms" class="divide-y" phx-update="stream">
          <div
            :for={{id, {room, joined?}} <- @streams.rooms}
            class="flex items-center justify-between p-4 cursor-pointer group first:rounded-t last:rounded-b"
            id={id}
            phx-click={JS.navigate(~p"/rooms/#{room}")}
          >
            <div>
              <div class="mb-1 font-medium">
                #<%= room.name %>
                <span class="mx-1 text-sm font-light text-gray-500 opacity-0 group-hover:opacity-100">
                  View room
                </span>
              </div>
              <div class="text-sm text-gray-500">
                <%= if joined? do %>
                  <span class="font-bold text-green-600">✓ Joined</span>
                <% end %>
                <%= if joined? && room.topic do %>
                  <span class="mx-1">·</span>
                <% end %>
                <%= if room.topic do %>
                  <%= room.topic %>
                <% end %>
              </div>
            </div>
            <button
              class="opacity-0 group-hover:opacity-100 bg-white hover:bg-gray-100 border border-gray-400 text-gray-700 px-3 py-1.5 w-24 rounded-sm font-bold"
              phx-click="toggle-room-membership"
              phx-value-id={room.id}
            >
              <%= if joined? do %>
                Leave
              <% else %>
                Join
              <% end %>
            </button>
          </div>
        </div>
      </div>
    </main>
    <.modal id="new-room-modal">
      <.header>New chat room</.header>

      <.live_component module={SlaxWeb.ChatRoomLive.FormComponent} id="new-room-form-component" />
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    rooms = Chat.list_rooms_with_joined(socket.assigns.current_user)

    socket
    |> assign(:page_title, "All rooms")
    |> stream_configure(:rooms, dom_id: fn {room, _} -> "rooms-#{room.id}" end)
    |> stream(:rooms, rooms)
    |> ok()
  end

  def handle_event("toggle-room-membership", %{"id" => id}, socket) do
    {room, joined?} =
      id
      |> Chat.get_room!()
      |> Chat.toggle_room_membership(socket.assigns.current_user)

    socket
    |> stream_insert(:rooms, {room, joined?})
    |> noreply()
  end
end
