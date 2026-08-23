defmodule AgentbotCore.Modules.Provisioning.Provider do
  @moduledoc """
  Provisioning provider'lar — fly.io, railway, render, aws...

  Affiliate URL şablonu, prerequisites ve metadata içerir.
  QM'deki "target.provider-registry" felsefesinden.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "provisioning_providers" do
    field(:name, :string)
    field(:slug, :string)

    field(:referral_url_template, :string)
    field(:referral_code, :string)

    field(:prerequisites, :map)
    field(:status, :string, default: "active")

    field(:metadata, :map)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :name,
      :slug,
      :referral_url_template,
      :referral_code,
      :prerequisites,
      :status,
      :metadata
    ])
    |> validate_required([:name, :slug, :referral_url_template])
    |> unique_constraint(:slug)
    |> validate_inclusion(:status, ["active", "inactive"])
  end
end
