defmodule SlaxWeb.ChatComponents do
  @moduledoc false
  use SlaxWeb, :html

  alias Slax.Accounts.User
  alias Slax.Chat.Message

  import SlaxWeb.UserComponents

  attr :current_user, User, required: true
  attr :dom_id, :string, required: true
  attr :message, :any, required: true
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
          phx-value-type={@message.__struct__ |> Module.split() |> List.last()}
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
          <div
            :if={is_struct(@message, Message) && Enum.any?(@message.reactions)}
            class="flex mt-2 space-x-2"
          >
            <%= for {emoji, count, me?} <- enumerate_reactions(@message.reactions, @current_user) do %>
              <button
                class={[
                  "flex items-center pl-2 pr-2 h-6 rounded-full text-xs",
                  me? && "bg-blue-100 border border-blue-400",
                  !me? && "bg-slate-200 hover:bg-slate-400"
                ]}
                phx-click={if me?, do: "remove-reaction", else: "add-reaction"}
                phx-value-emoji={emoji}
                phx-value-message_id={@message.id}
              >
                <span><%= emoji %></span>
                <span class="ml-1 font-medium"><%= count %></span>
              </button>
            <% end %>
          </div>
          <div
            :if={!@in_thread? && Enum.any?(@message.replies)}
            class="box-border inline-flex items-center py-1 pr-2 mt-2 border border-transparent rounded cursor-pointer hover:border-slate-200 hover:bg-slate-50"
            phx-click="show-thread"
            phx-value-id={@message.id}
          >
            <.thread_avatars replies={@message.replies} />
            <a class="inline-block ml-1 text-xs font-medium text-blue-600" href="#">
              <%= length(@message.replies) %>
              <%= if length(@message.replies) == 1 do %>
                reply
              <% else %>
                replies
              <% end %>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp enumerate_reactions(reactions, current_user) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, reactions} ->
      me? = Enum.any?(reactions, &(&1.user_id == current_user.id))

      {emoji, length(reactions), me?}
    end)
  end

  defp thread_avatars(assigns) do
    users =
      assigns.replies
      |> Enum.map(& &1.user)
      |> Enum.uniq_by(& &1.id)

    assigns = assign(assigns, :users, users)

    ~H"""
    <.user_avatar :for={user <- @users} class={["h-6 w-6 rounded flex-shrink-0 ml-1"]} user={user} />
    """
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end
end
