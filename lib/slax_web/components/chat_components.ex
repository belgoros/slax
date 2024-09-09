defmodule SlaxWeb.ChatComponents do
  @moduledoc false
  use SlaxWeb, :html

  alias Slax.Accounts.User
  alias Slax.Chat.Message

  import SlaxWeb.UserComponents

  attr :current_user, User, required: true
  attr :dom_id, :string, required: true
  attr :message, Message, required: true
  attr :in_thread?, :boolean, default: false
  attr :timezone, :string, required: true

  def message(assigns) do
    ~H"""
    <div id={@dom_id} class="relative flex px-4 py-3 group">
      <div
        :if={!@in_thread? || @current_user.id == @message.user_id}
        class="absolute hidden gap-1 px-2 pb-1 bg-white border rounded shadow-sm top-4 right-4 group-hover:block border-px border-slate-300"
      >
        <button
          :if={!@in_thread?}
          phx-click="show-thread"
          phx-value-id={@message.id}
          class="cursor-pointer text-slate-500 hover:text-slate-600"
        >
          <.icon name="hero-chat-bubble-bottom-center-text" class="w-4 h-4" />
        </button>

        <button
          :if={@current_user.id == @message.user_id}
          class="text-red-500 cursor-pointer hover:text-red-800"
          data-confirm="Are you sure?"
          phx-click="delete-message"
          phx-value-id={@message.id}
        >
          <.icon name="hero-trash" class="w-4 h-4" />
        </button>
      </div>
      <.user_avatar
        user={@message.user}
        class="w-10 h-10 rounded cursor-pointer"
        phx-click="show-profile"
        phx-value-user-id={@message.user.id}
      />
      <div class="ml-2">
        <div class="-mt-1">
          <.link
            phx-click="show-profile"
            phx-value-user-id={@message.user.id}
            class="text-sm font-semibold hover:underline"
          >
            <%= @message.user.username %>
          </.link>
          <span :if={@timezone} class="ml-1 text-xs text-gray-500">
            <%= message_timestamp(@message, @timezone) %>
          </span>
          <p class="text-sm"><%= @message.body %></p>
        </div>
      </div>
    </div>
    """
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end
end
