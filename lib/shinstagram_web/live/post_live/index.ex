defmodule ShinstagramWeb.PostLive.Index do
  alias Shinstagram.Logs
  use ShinstagramWeb, :live_view

  alias Shinstagram.Profiles
  alias Shinstagram.Timeline
  alias Shinstagram.Timeline.Post
  alias Shinstagram.Repo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Timeline.subscribe()
      Phoenix.PubSub.subscribe(Shinstagram.PubSub, "feed")
    end

    {:ok,
     socket
     |> stream(:posts, Timeline.list_recent_posts(100))
     |> stream(:logs, Logs.list_recent_logs_with_profile(50))}
  end

  def handle_info({"profile_activity", _event, log}, socket) do
    {:noreply, socket |> stream_insert(:logs, log, at: 0)}
  end

  def handle_info({:post_created, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: 0)}
  end

  def handle_info({:post_updated, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({ShinstagramWeb.PostLive.FormComponent, {:saved, post}}, socket) do
    {:noreply, stream_insert(socket, :posts, post)}
  end

  def handle_event("post", %{"username" => username}, socket) do
    profile = Profiles.get_profile_by_username!(username)
    [post] = Timeline.list_recent_posts(1)

    Timeline.create_like(profile, post)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Timeline")
    |> assign(:post, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %Post{})
  end

  def handle_event("wake-up", _, socket) do
    Phoenix.PubSub.broadcast(Shinstagram.PubSub, "wake-up-alarm", :kickoff)
    {:noreply, socket}
  end

  def handle_event("sleep", _, socket) do
    Profiles.list_awake_profiles()
    |> Enum.map(fn profile -> Shinstagram.Agents.Profile.shutdown_profile(profile.pid) end)

    {:noreply, socket}
  end

  def handle_event("like", %{"post_id" => id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"post-id" => id} = params, socket) do
    post = Timeline.get_post!(id)

    Timeline.list_comments(post)
    |> Enum.each(&Timeline.delete_comment/1)

    Timeline.get_likes_by_post_id(post.id)
    |> Enum.each(&Timeline.delete_like/1)

    {:ok, _} = Timeline.delete_post(post)

    {:noreply, stream_delete(socket, :posts, post)}
  end

  def handle_info({:like, username, post_id}, socket) do
    profile = Shinstagram.Profiles.get_profile_by_username!(username)
    post = Shinstagram.Timeline.get_post!(post_id)
    Shinstagram.Timeline.create_like(profile, post)

    {:noreply, socket |> stream_insert(:posts, post)}
  end
end
