defmodule SlaxWeb.ChatRoomLive.ThreadComponent do
  use SlaxWeb, :live_component

  alias Slax.Chat
  alias Slax.Chat.Reply

  import SlaxWeb.ChatComponents

  def render(assigns) do
    ~H"""
    <div
      class="flex flex-col flex-shrink-0 w-1/4 max-w-xs border-l border-slate-300 bg-slate-100"
      id="thread-component"
      phx-hook="Thread"
    >
      <div class="flex items-center flex-shrink-0 h-16 px-4 border-b border-slate-300">
        <div>
          <h2 class="text-sm font-semibold leading-none">Thread</h2>
          <a class="text-xs leading-none" href="#">#<%= @room.name %></a>
        </div>
        <button
          class="flex items-center justify-center w-6 h-6 ml-auto rounded hover:bg-gray-300"
          phx-click="close-thread"
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>
      <div id="thread-message-with-replies" class="flex flex-col flex-grow overflow">
        <div class="border-b border-slate-300">
          <.message
            message={@message}
            dom_id="thread-message"
            current_user={@current_user}
            in_thread?
            timezone={@timezone}
          />
        </div>
        <div id="thread-replies" phx-update="stream">
          <.message
            :for={{dom_id, reply} <- @streams.replies}
            current_user={@current_user}
            dom_id={dom_id}
            message={reply}
            in_thread?
            timezone={@timezone}
          />
        </div>
      </div>
      <div class="px-4 pt-3 mt-auto bg-slate-100">
        <div :if={@joined?} class="h-12 pb-4">
          <.form
            class="flex items-center p-1 border-2 rounded-sm border-slate-300"
            for={@form}
            id="new-reply-form"
            phx-change="validate-reply"
            phx-submit="submit-reply"
            phx-target={@myself}
          >
            <textarea
              class="flex-grow px-3 mx-1 text-sm border-l resize-none border-slate-300 bg-slate-50"
              cols=""
              id="thread-message-textarea"
              name={@form[:body].name}
              phx-debounce
              phx-hook="ChatMessageTextarea"
              placeholder="Reply…"
              rows="1"
            ><%= Phoenix.HTML.Form.normalize_value("textarea", @form[:body].value) %></textarea>
            <button class="flex items-center justify-center flex-shrink w-6 h-6 rounded hover:bg-slate-200">
              <.icon name="hero-paper-airplane" class="w-4 h-4" />
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def update(assigns, socket) do
    socket
    |> assign_form(Chat.change_reply(%Reply{}))
    |> stream(:replies, assigns.message.replies, reset: true)
    |> assign(assigns)
    |> ok()
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  def handle_event("submit-reply", %{"reply" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    if !Chat.joined?(room, current_user) do
      raise "not allowed"
    end

    case Chat.create_reply(
           socket.assigns.message,
           message_params,
           socket.assigns.current_user
         ) do
      {:ok, _message} ->
        assign_form(socket, Chat.change_reply(%Reply{}))

      {:error, changeset} ->
        assign_form(socket, changeset)
    end
    |> noreply()
  end

  def handle_event("validate-reply", %{"reply" => message_params}, socket) do
    changeset = Chat.change_reply(%Reply{}, message_params)

    {:noreply, assign_form(socket, changeset)}
  end
end
