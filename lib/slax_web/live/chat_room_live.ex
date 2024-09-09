defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Chat
  alias Slax.Accounts.User
  alias Slax.Chat.{Room, Message}
  alias Slax.Accounts
  alias SlaxWeb.OnlineUsers
  alias SlaxWeb.ChatRoomLive.ThreadComponent

  import SlaxWeb.ChatComponents
  import SlaxWeb.UserComponents

  def mount(_params, _session, socket) do
    rooms = Chat.list_joined_rooms_with_unread_counts(socket.assigns.current_user)
    users = Accounts.list_users()

    timezone = get_connect_params(socket)["timezone"]

    if connected?(socket) do
      OnlineUsers.track(self(), socket.assigns.current_user)
    end

    OnlineUsers.subscribe()

    Accounts.subscribe_to_user_avatars()

    Enum.each(rooms, fn {chat, _} -> Chat.subscribe_to_room(chat) end)

    socket
    |> assign(rooms: rooms, timezone: timezone, users: users)
    |> assign(online_users: OnlineUsers.list())
    |> stream_configure(:messages,
      dom_id: fn
        %Message{id: id} -> "messages-#{id}"
        :unread_marker -> "messages-unread-marker"
        %Date{} = date -> to_string(date)
      end
    )
    |> ok()
  end

  def handle_params(params, _session, socket) do
    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Chat.get_room!(id)

        :error ->
          Chat.get_first_room!()
      end

    last_read_id = Chat.get_last_read_id(room, socket.assigns.current_user)

    messages =
      room
      |> Chat.list_messages_in_room()
      |> insert_date_dividers(socket.assigns.timezone)
      |> maybe_insert_unread_marker(last_read_id)

    Chat.update_last_read_id(room, socket.assigns.current_user)

    socket
    |> assign(
      hide_topic?: false,
      joined?: Chat.joined?(room, socket.assigns.current_user),
      page_title: "#" <> room.name,
      room: room
    )
    |> stream(:messages, messages, reset: true)
    |> assign_message_form(Chat.change_message(%Message{}))
    |> push_event("scroll_messages_to_bottom", %{})
    |> update(:rooms, fn rooms ->
      room_id = room.id

      Enum.map(rooms, fn
        {%Room{id: ^room_id} = room, _} -> {room, 0}
        other -> other
      end)
    end)
    |> noreply()
  end

  defp insert_date_dividers(messages, nil), do: messages

  defp insert_date_dividers(messages, timezone) do
    messages
    |> Enum.group_by(fn message ->
      message.inserted_at
      |> DateTime.shift_zone!(timezone)
      |> DateTime.to_date()
    end)
    |> Enum.sort_by(fn {date, _msgs} -> date end, &(Date.compare(&1, &2) != :gt))
    |> Enum.flat_map(fn {date, messages} -> [date | messages] end)
  end

  defp maybe_insert_unread_marker(messages, nil), do: messages

  defp maybe_insert_unread_marker(messages, last_read_id) do
    {read, unread} =
      Enum.split_while(messages, fn
        %Message{} = message -> message.id <= last_read_id
        _ -> true
      end)

    if unread == [] do
      read
    else
      read ++ [:unread_marker | unread]
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col flex-shrink-0 w-64 bg-slate-100">
      <div class="flex items-center justify-between flex-shrink-0 h-16 px-4 border-b border-slate-300">
        <div class="flex flex-col gap-1.5">
          <h1 class="text-lg font-bold text-gray-800">
            Slax
          </h1>
        </div>
      </div>
      <div class="mt-4 overflow-auto">
        <div class="flex items-center h-8 px-3 group" phx-click={JS.toggle(to: "#rooms-list")}>
          <.toggler on_click={toggle_rooms()} dom_id="rooms-toggler" text="Rooms" />
        </div>
        <div id="rooms-list">
          <.room_link
            :for={{room, unread_count} <- @rooms}
            room={room}
            active={room.id == @room.id}
            unread_count={unread_count}
          />
          <button class="relative flex items-center w-full h-8 pl-8 pr-3 text-sm cursor-pointer group hover:bg-slate-300">
            <.icon name="hero-plus" class="relative w-4 h-4 top-px" />
            <span class="ml-2 leading-none">Add rooms</span>
            <div class="absolute hidden py-3 bg-white border rounded-lg cursor-default group-focus:block top-8 right-2 border-slate-200">
              <div class="w-full text-left">
                <div class="hover:bg-sky-600">
                  <div
                    class="block px-6 py-1 text-gray-800 cursor-pointer whitespace-nowrap hover:text-white"
                    phx-click={JS.navigate(~p"/rooms/#{@room}/new") |> show_modal("new-room-modal")}
                  >
                    Create a new room
                  </div>
                </div>
                <div class="hover:bg-sky-600">
                  <div
                    phx-click={JS.navigate(~p"/rooms")}
                    class="px-6 py-1 text-gray-800 cursor-pointer whitespace-nowrap hover:text-white"
                  >
                    Browse rooms
                  </div>
                </div>
              </div>
            </div>
          </button>
        </div>
        <div class="mt-4">
          <div class="flex items-center h-8 px-3 group">
            <div class="flex items-center flex-grow focus:outline-none">
              <.toggler on_click={toggle_users()} dom_id="users-toggler" text="Users" />
            </div>
          </div>
          <div id="users-list">
            <.user
              :for={user <- @users}
              user={user}
              online={OnlineUsers.online?(@online_users, user.id)}
            />
          </div>
        </div>
      </div>
    </div>
    <div class="flex flex-col flex-grow shadow-lg">
      <div class="flex items-center justify-between flex-shrink-0 h-16 px-4 bg-white border-b border-slate-300">
        <div class="flex flex-col gap-1.5">
          <h1 class="text-sm font-bold leading-none">
            #<%= @room.name %>
          </h1>
          <.link
            :if={@joined?}
            class="text-xs font-normal text-blue-600 hover:text-blue-700"
            navigate={~p"/rooms/#{@room}/edit"}
          >
            Edit
          </.link>
          <div class="text-xs leading-none h-3.5" phx-click="toggle-topic">
            <%= if @hide_topic? do %>
              <span class="text-slate-600">[Topic hidden]</span>
            <% else %>
              <%= @room.topic %>
            <% end %>
          </div>
        </div>
        <ul class="relative z-10 flex items-center justify-end gap-4 px-4 sm:px-6 lg:px-8">
          <li class="text-[0.8125rem] leading-6 text-zinc-900">
            <div class="text-sm leading-10">
              <.link
                class="flex items-center gap-4"
                phx-click="show-profile"
                phx-value-user-id={@current_user.id}
              >
                <.user_avatar user={@current_user} class="w-8 h-8 rounded" />
                <span class="hover:underline"><%= @current_user.username %></span>
              </.link>
            </div>
          </li>
          <li>
            <.link
              href={~p"/users/log_out"}
              method="delete"
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Log out
            </.link>
          </li>
        </ul>
      </div>
      <div
        id="room-messages"
        class="flex flex-col flex-grow overflow-auto"
        phx-update="stream"
        phx-hook="RoomMessages"
      >
        <%= for {dom_id, message} <- @streams.messages do %>
          <%= case message do %>
            <% :unread_marker -> %>
              <div id={dom_id} class="flex items-center w-full gap-3 pr-5 text-red-500">
                <div class="w-full h-px bg-red-500 grow"></div>
                <div class="text-sm">New</div>
              </div>
            <% %Message{} -> %>
              <.message
                current_user={@current_user}
                dom_id={dom_id}
                message={message}
                timezone={@timezone}
              />
            <% %Date{} -> %>
              <div id={dom_id} class="flex flex-col items-center mt-2">
                <hr class="w-full" />
                <span class="flex items-center justify-center h-6 px-3 mx-auto -mt-3 text-xs font-semibold bg-white border rounded-full">
                  <%= format_date(message) %>
                </span>
              </div>
          <% end %>
        <% end %>
      </div>
      <div :if={@joined?} class="h-12 px-4 pb-4 bg-white">
        <.form
          id="new-message-form"
          for={@new_message_form}
          phx-change="validate-message"
          phx-submit="submit-message"
          class="flex items-center p-1 border-2 rounded-sm border-slate-300"
        >
          <textarea
            class="flex-grow px-3 mx-1 text-sm border-l resize-none border-slate-300"
            cols=""
            id="chat-message-textarea"
            name={@new_message_form[:body].name}
            phx-hook="ChatMessageTextarea"
            placeholder={"Message ##{@room.name}"}
            phx-debounce
            rows="1"
          >
        <%= Phoenix.HTML.Form.normalize_value("textarea", @new_message_form[:body].value) %>
        </textarea>
          <button class="flex items-center justify-center flex-shrink w-6 h-6 rounded hover:bg-slate-200">
            <.icon name="hero-paper-airplane" class="w-4 h-4" />
          </button>
        </.form>
      </div>
      <div
        :if={!@joined?}
        class="flex justify-around p-6 mx-5 mb-5 border rounded-lg bg-slate-100 border-slate-300"
      >
        <div class="text-center max-w-3-xl">
          <div class="mb-4">
            <h1 class="text-xl font-semibold">#<%= @room.name %></h1>
            <p :if={@room.topic} class="mt-1 text-sm text-gray-600"><%= @room.topic %></p>
          </div>
          <div class="flex items-center justify-around">
            <button
              phx-click="join-room"
              class="px-4 py-2 text-white bg-green-600 rounded hover:bg-green-600 focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              Join Room
            </button>
          </div>
          <div class="mt-4">
            <.link
              navigate={~p"/rooms"}
              href="#"
              class="text-sm underline text-slate-500 hover:text-slate-600"
            >
              Back to All Rooms
            </.link>
          </div>
        </div>
      </div>
    </div>
    <%= if assigns[:profile] do %>
      <.live_component
        id="profile"
        module={SlaxWeb.ChatRoomLive.ProfileComponent}
        user={@profile}
        current_user={@current_user}
      />
    <% end %>

    <%= if assigns[:thread] do %>
      <.live_component
        id="thread"
        module={ThreadComponent}
        current_user={@current_user}
        message={@thread}
        room={@room}
        timezone={@timezone}
      />
    <% end %>

    <.modal
      id="new-room-modal"
      show={@live_action == :new}
      on_cancel={JS.navigate(~p"/rooms/#{@room}")}
    >
      <.header>New chat room</.header>
      <.live_component
        module={SlaxWeb.ChatRoomLive.FormComponent}
        id="new-room-form-component"
        current_user={@current_user}
      />
    </.modal>
    """
  end

  defp format_date(%Date{} = date) do
    today = Date.utc_today()

    case Date.diff(today, date) do
      0 ->
        "Today"

      1 ->
        "Yesterday"

      _ ->
        format_str = "%A, %B %e#{ordinal(date.day)}#{if today.year != date.year, do: " %Y"}"
        Timex.format!(date, format_str, :strftime)
    end
  end

  defp ordinal(day) do
    cond do
      rem(day, 10) == 1 and day != 11 -> "st"
      rem(day, 10) == 2 and day != 12 -> "nd"
      rem(day, 10) == 3 and day != 13 -> "rd"
      true -> "th"
    end
  end

  attr :dom_id, :string, required: true
  attr :on_click, JS, required: true
  attr :text, :string, required: true

  defp toggler(assigns) do
    ~H"""
    <button id={@dom_id} phx-click={@on_click} class="flex items-center flex-grow focus:outline-none">
      <.icon id={@dom_id <> "-chevron-down"} name="hero-chevron-down" class="w-4 h-4" />
      <.icon
        id={@dom_id <> "-chevron-right"}
        name="hero-chevron-right"
        class="w-4 h-4"
        style="display:none;"
      />
      <span class="ml-2 text-sm font-medium leading-none">
        <%= @text %>
      </span>
    </button>
    """
  end

  attr :count, :integer, required: true

  defp unread_message_counter(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      class="flex items-center justify-center h-5 px-2 ml-auto text-xs font-medium text-white bg-blue-500 rounded-full"
    >
      <%= @count %>
    </span>
    """
  end

  attr :user, User, required: true
  attr :online, :boolean, default: false

  defp user(assigns) do
    ~H"""
    <.link class="flex items-center h-8 pl-8 pr-3 text-sm hover:bg-gray-300" href="#">
      <div class="flex justify-center w-4">
        <%= if @online do %>
          <span class="w-2 h-2 bg-blue-500 rounded-full"></span>
        <% else %>
          <span class="w-2 h-2 border-2 border-gray-500 rounded-full"></span>
        <% end %>
      </div>
      <span class="ml-2 leading-none"><%= @user.username %></span>
    </.link>
    """
  end

  attr :active, :boolean, required: true
  attr :room, Room, required: true
  attr :unread_count, :integer, required: true

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
      <.unread_message_counter count={@unread_count} />
    </.link>
    """
  end

  def handle_event("show-profile", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    {:noreply, assign(socket, profile: user, thread: nil)}
  end

  def handle_event("toggle-topic", _params, socket) do
    {:noreply, update(socket, :hide_topic?, &(!&1))}
  end

  def handle_event("validate-message", %{"message" => message_params}, socket) do
    changeset = Chat.change_message(%Message{}, message_params)

    {:noreply, assign_message_form(socket, changeset)}
  end

  def handle_event("close-profile", _, socket) do
    {:noreply, assign(socket, :profile, nil)}
  end

  def handle_event("submit-message", %{"message" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    socket =
      if Chat.joined?(room, current_user) do
        case Chat.create_message(room, message_params, current_user) do
          {:ok, _message} ->
            assign_message_form(socket, Chat.change_message(%Message{}))

          {:error, changeset} ->
            assign_message_form(socket, changeset)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("close-thread", _, socket) do
    {:noreply, assign(socket, :thread, nil)}
  end

  def handle_event("delete-message", %{"id" => id, "type" => "Message"}, socket) do
    Chat.delete_message_by_id(id, socket.assigns.current_user)
    {:noreply, socket}
  end

  def handle_event("delete-message", %{"id" => id, "type" => "Reply"}, socket) do
    Chat.delete_reply_by_id(id, socket.assigns.current_user)

    {:noreply, socket}
  end

  def handle_event("show-thread", %{"id" => message_id}, socket) do
    message = Chat.get_message!(message_id)

    socket |> assign(profile: nil, thread: message) |> noreply()
  end

  def handle_event("join-room", _, socket) do
    current_user = socket.assigns.current_user
    Chat.join_room!(socket.assigns.room, current_user)
    Chat.subscribe_to_room(socket.assigns.room)

    socket =
      assign(socket,
        joined?: true,
        rooms: Chat.list_joined_rooms_with_unread_counts(current_user)
      )

    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    room = socket.assigns.room

    socket =
      cond do
        message.room_id == room.id ->
          Chat.update_last_read_id(room, socket.assigns.current_user)

          socket
          |> stream_insert(:messages, message)
          |> push_event("scroll_messages_to_bottom", %{})

        message.user_id != socket.assigns.current_user.id ->
          update(socket, :rooms, fn rooms ->
            Enum.map(rooms, fn
              {%Room{id: id} = room, count} when id == message.room_id -> {room, count + 1}
              other -> other
            end)
          end)

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    online_users = OnlineUsers.update(socket.assigns.online_users, diff)

    {:noreply, assign(socket, online_users: online_users)}
  end

  def handle_info({:deleted_reply, message}, socket) do
    if message.room_id == socket.assigns.room.id do
      socket = stream_insert(socket, :messages, message)

      if socket.assigns[:thread] && socket.assigns.thread.id == message.id do
        assign(socket, :thread, message)
      else
        socket
      end
    else
      socket
    end
    |> noreply()
  end

  def handle_info({:updated_avatar, user}, socket) do
    socket
    |> maybe_update_profile(user)
    |> maybe_update_current_user(user)
    |> push_event("update_avatar", %{user_id: user.id, avatar_path: user.avatar_path})
    |> noreply()
  end

  defp maybe_update_current_user(socket, user) do
    if socket.assigns.current_user.id == user.id do
      assign(socket, :current_user, user)
    else
      socket
    end
  end

  defp maybe_update_profile(socket, user) do
    if socket.assigns[:profile] && socket.assigns.profile.id == user.id do
      assign(socket, :profile, user)
    else
      socket
    end
  end

  defp assign_message_form(socket, changeset) do
    assign(socket, :new_message_form, to_form(changeset))
  end

  defp toggle_rooms() do
    JS.toggle(to: "#rooms-toggler-chevron-down")
    |> JS.toggle(to: "#rooms-toggler-chevron-right")
    |> JS.toggle(to: "#rooms-list")
  end

  defp toggle_users() do
    JS.toggle(to: "#users-toggler-chevron-down")
    |> JS.toggle(to: "#users-toggler-chevron-right")
    |> JS.toggle(to: "#users-list")
  end
end
