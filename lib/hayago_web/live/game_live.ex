defmodule HayagoWeb.GameLive do
  use Phoenix.LiveView
  alias Hayago.Game

  def render(assigns) do
    HayagoWeb.GameView.render("index.html", assigns)
  end

  def handle_params(%{"name" => name} = _params, _uri, socket) do
    :ok = Phoenix.PubSub.subscribe(Hayago.PubSub, name)
    {:noreply, assign_game(socket, name)}
  end

  def handle_params(_params, _uri, socket) do
    name =
      ?a..?z
      |> Enum.take_random(6)
      |> List.to_string()

    {:ok, _pid} =
      DynamicSupervisor.start_child(Hayago.GameSupervisor, {Game, name: via_tuple(name)})

    {:noreply,
     live_redirect(
       socket,
       to: HayagoWeb.Router.Helpers.live_path(socket, HayagoWeb.GameLive, name: name)
     )}
  end

  # def mount(_session, socket) do
  #   name =
  #     ?a..?z
  #     |> Enum.take_random()
  #     |> List.to_string()
  #
  #   {:ok, _pid} =
  #     DynamicSupervisor.start_child(Hayago.GameSupervisor, {Game, name: via_tuple(name)})
  #
  #   {:ok, assign_game(socket, name)}
  # end

  def handle_event("place", %{"index" => index}, %{assigns: %{name: name}} = socket) do
    :ok = GenServer.cast(via_tuple(name), {:place, String.to_integer(index)})
    :ok = Phoenix.PubSub.broadcast(Hayago.PubSub, name, :update)
    {:noreply, assign_game(socket)}
  end

  def handle_event("jump", %{"destination" => destination}, %{assigns: %{name: name}} = socket) do
    :ok = GenServer.cast(via_tuple(name), {:jump, String.to_integer(destination)})
    :ok = Phoenix.PubSub.broadcast(Hayago.PubSub, name, :update)
    {:noreply, assign_game(socket)}
  end

  def handle_info(:update, socket) do
    {:noreply, assign_game(socket)}
  end

  defp via_tuple(name) do
    {:via, Registry, {Hayago.GameRegistry, name}}
  end

  defp assign_game(socket, name) do
    socket
    |> assign(name: name)
    |> assign_game()
  end

  defp assign_game(%{assigns: %{name: name}} = socket) do
    game = GenServer.call(via_tuple(name), :game)
    assign(socket, game: game, state: Game.state(game))
  end
end
