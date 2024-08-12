defmodule SlaxWeb.ChatRoomLive.Index do
  use SlaxWeb, :live_view

  alias Slax.Chat

  def render(assigns) do
    ~H"""
    <main class="flex-1 max-w-4xl p-6 mx-auto">
      <div class="mb-4">
        <h1 class="text-xl font-semibold"><%= @page_title %></h1>
      </div>
      <div class="border rounded bg-slate-50">
        <div id="rooms" class="divide-y" phx-update="stream">
          <div
            :for={{id, room} <- @streams.rooms}
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
                <%= if room.topic do %>
                  <%= room.topic %>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end

  def mount(_params, _session, socket) do
    rooms = Chat.list_rooms()
    socket = socket |> assign(page_title: "All rooms") |> stream(:rooms, rooms)
    {:ok, socket}
  end
end
