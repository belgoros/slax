defmodule Slax.Chat.RoomMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "room_memberships" do

    field :user_id, :id
    field :room_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room_membership, attrs) do
    room_membership
    |> cast(attrs, [])
    |> validate_required([])
  end
end
