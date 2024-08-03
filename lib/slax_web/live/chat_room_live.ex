defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Repo
  alias Slax.Chat.Room

  def mount(_params, _session, socket) do
    room = Room |> Repo.all() |> List.first()

    {:ok, assign(socket, :room, room)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col flex-grow shadow-lg">
      <div class="flex items-center justify-between flex-shrink-0 h-16 px-4 bg-white border-b border-slate-300">
        <div class="flex flex-col gap-1.5">
          <h1 class="text-sm font-bold leading-none">
            #<%= @room.name %>
          </h1>
          <div class="text-xs leading-none h-3.5"><%= @room.topic %></div>
        </div>
      </div>
    </div>
    """
  end
end
