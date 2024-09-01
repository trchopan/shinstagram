defmodule Shinstagram.AI do
  alias Ecto.UUID

  def parse_chat({:ok, %{choices: [%{"message" => %{"content" => content}} | _]}}),
    do: {:ok, content}

  def parse_chat({:error, %{"error" => %{"message" => message}}}), do: {:error, message}

  def save_r2(image_binary, uuid) do
    file_name = "prediction-#{uuid}.png"
    bucket = System.get_env("BUCKET_NAME")

    %{status_code: 200} =
      ExAws.S3.put_object(bucket, file_name, image_binary)
      |> ExAws.request!()

    {:ok, "#{System.get_env("CLOUDFLARE_PUBLIC_URL")}/#{file_name}"}
  end

  def random_image() do
    category =
      [
        "nature",
        "city",
        "technology",
        "food",
        "still_life",
        "abstract",
        "wildlife"
      ]
      |> Enum.random()

    body =
      Req.get!("https://api.api-ninjas.com/v1/randomimage?category=" <> category,
        headers: [x_api_key: System.get_env("NINJA_API_KEY")]
      ).body

    Base.decode64!(body)
  end

  def gen_image({:ok, image_prompt}), do: gen_image(image_prompt)

  @doc """
  Generates an image given a prompt. Returns {:ok, url} or {:error, error}.
  """
  def gen_image(image_prompt) when is_binary(image_prompt) do
    model = Replicate.Models.get!("adirik/flux-cinestill")

    version =
      Replicate.Models.get_version!(
        model,
        "216a43b9975de9768114644bbf8cd0cba54a923c6d0f65adceaccfc9383a938f"
      )

    with {:ok, prediction} <- Replicate.Predictions.create(version, %{prompt: image_prompt}),
         {:ok, prediction} = Replicate.Predictions.wait(prediction) do
      Logger.info("Image generated: #{prediction.output}")

      List.first(prediction.output)
      |> then(fn image_url -> Req.get!(image_url).body end)
      |> save_r2(prediction.id)
    else
      {:error, _error} ->
        random_image() |> save_r2(UUID.generate())
    end
  end

  def chat_completion(text) do
    text
    |> OpenAI.chat_completion()
    |> parse_chat()
  end
end
