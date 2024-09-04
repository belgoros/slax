defmodule SlaxWeb.ChatRoomLive.ProfileComponent do
  use SlaxWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col flex-shrink-0 w-1/4 max-w-xs bg-white shadow-xl">
      <div class="flex items-center h-16 px-4 border-b border-slate-300">
        <div class="">
          <h2 class="text-lg font-bold text-gray-800">
            Profile
          </h2>
        </div>
        <button
          class="flex items-center justify-center w-6 h-6 ml-auto rounded hover:bg-gray-300"
          phx-click="close-profile"
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>
      <div class="flex flex-col flex-grow p-4 overflow-auto">
        <div class="mb-4">
          <img src={~p"/images/one_ring.jpg"} class="w-48 mx-auto rounded" />
        </div>
        <h2 class="text-xl font-bold text-gray-800">
          <%= @user.username %>
        </h2>
      </div>
    </div>
    """
  end
end
