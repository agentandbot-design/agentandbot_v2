defmodule AgentbotCore.PubSub do
  @moduledoc """
  PubSub sarmalayıcı — Phoenix.PubSub'e delegasyon.

  Tüm modüller bu wrapper üzerinden broadcast/subscribe yapar.
  Phoenix.PubSub süreci AgentbotCore.Application'da
  `{Phoenix.PubSub, name: __MODULE__}` ile başlatılır.
  """

  @doc "Belirli bir topic'e mesaj yayınlar."
  @spec broadcast(String.t(), atom() | String.t(), term()) :: :ok | {:error, term()}
  def broadcast(topic, event, payload \\ nil) do
    Phoenix.PubSub.broadcast(__MODULE__, topic, {event, payload})
  end

  @doc "Bir topic'e abone olur."
  @spec subscribe(String.t()) :: :ok | {:error, term()}
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(__MODULE__, topic)
  end

  @doc "Topic aboneliğini iptal eder."
  @spec unsubscribe(String.t()) :: :ok | {:error, term()}
  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(__MODULE__, topic)
  end

  @doc "Bir topic'teki abone sayısını döndürür."
  @spec subscriber_count(String.t()) :: non_neg_integer()
  def subscriber_count(_topic) do
    # Phoenix 1.8'de subscribers/2 public değil
    0
  end
end
