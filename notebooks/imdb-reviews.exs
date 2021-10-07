# IMDB Reviews Classification

## Load deps
Mix.install(
  [
    {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "nx", override: true},
    {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla", override: true},
    # {:axon, "~> 0.1.0-dev", github: "elixir-nx/axon", branch: "main"},
    {:axon, "~> 0.1.0-dev", github: "arpieb/axon", branch: "fix-metrics-epoch-logging"},
    {:scidata, "~> 0.1.2"},
    {:nltex, "~> 0.1.0-dev", github: "arpieb/nltex", branch: "master", override: true}
  ]
  # , force: true
)
Application.put_env(:exla, :clients, default: [platform: :cuda])

defmodule IMDBReviews do
  @default_defn_compiler EXLA

  require Axon

  import Nx.Defn

  def preproc_reviews(reviews, w2v) do
    reviews
    |> Stream.map(&String.downcase/1)
    |> Stream.map(&String.split/1)
    |> Stream.map(fn tokens -> {tokens, length(tokens)} end)
    |> Stream.map(fn {tokens, len} ->
      NLTEx.WordVectors.vectorize_tokens(tokens, w2v)
      |> Nx.stack()
      |> nx_proc(length: 150 - len)
      # |> Nx.pad(0.0, [{0, 150 - len, 0}, {0, 0, 0}])
      # |> Nx.transpose()
    end)
    |> Enum.to_list()
    |> Nx.stack()
    end

    defn nx_proc(t, opts \\ []) do
      t
      |> Nx.pad(0.0, [{0, opts[:length], 0}, {0, 0, 0}])
      |> Nx.transpose()
    end

    def download_w2v() do
      read_w2v = fn ifs ->
        IO.binread(ifs, :all)
        |> :erlang.binary_to_term()
      end

      write_w2v = fn w2v ->
        File.open!("/tmp/w2v.bin", [:write, :binary])
        |> IO.binwrite(w2v |> :erlang.term_to_binary())
        |> File.close()

        w2v
      end

      case File.open("/tmp/w2v.bin", [:read, :binary], read_w2v) do
        {:ok, data} ->
          data

        {:error, _} ->
          NLTEx.WordVectors.GloVe.download(:glove_6b, 50, base_url: "http://localhost:8080/")
          |> write_w2v.()
      end
    end

    def test_mode(model, final_params, vec_our_reviews) do
      yhat = Axon.predict(model, final_params[:params], vec_our_reviews)
      Nx.sum(yhat, axes: [0])
    end

end

## Retrieve IMDB movie reviews
reviews = Scidata.IMDBReviews.download()

IO.puts(length(reviews.review))
IO.puts(length(reviews.sentiment))

## Retrieve Stanford NLP's GloVe word vectors
w2v = IMDBReviews.download_w2v()
w2v.wordvecs |> Map.keys() |> length() |> IO.puts()

## Prepare review text data
num_samples = length(reviews.review)
vec_reviews =
  reviews.review
  |> Stream.take(num_samples)
  |> IMDBReviews.preproc_reviews(w2v)


## Prep sentiment labels
labels =
  reviews.sentiment
  |> Enum.take(num_samples)
  |> Nx.tensor(type: {:f, 32})
  |> Nx.new_axis(-1)
  |> Nx.equal(Nx.iota({2}))

Nx.sum(labels, axes: [0]) |> IO.puts()

## Construct Axon binary classification model and train it!
model =
  Axon.input({nil, 50, 150})
  |> Axon.conv(4, kernel_size: 2, activation: :relu)
  |> Axon.max_pool(kernel_size: 2)
  |> Axon.flatten()
  |> Axon.dense(1024, activation: :relu)
  |> Axon.dense(1024, activation: :relu)
  |> Axon.dense(2, activation: :softmax)
  |> IO.inspect()

batch_size = 32
train_x = vec_reviews |> Nx.to_batched_list(batch_size)
train_y = labels |> Nx.to_batched_list(batch_size)

final_params =
  model
  |> Axon.Training.step(:categorical_cross_entropy, Axon.Optimizers.adamw(0.005), metrics: [:accuracy])
  |> Axon.Training.train(train_x, train_y, epochs: 3, compiler: EXLA)

## Testing time!
our_reviews = [
  "This movie was great really enjoyed it loved it",
  "Meh, I could take it or leave it",
  "this movie was the worst and sucked",
  "I love this movie like no other. Another time I will try to explain its virtues to the uninitiated, but for the moment let me quote a few of pieces the remarkable dialogue, which, please remember, is all tongue in cheek. Aussies and Poms will understand, everyone else-well?<br /><br />(title song lyric)\"he can sink a beer, he can pick a queer, in his latest double-breasted Bondi gear.\"<br /><br />(another song lyric) \"All pommies are bastards, bastards, or worse, and England is the a**e-hole of the universe.\"<br /><br />(during a television interview on an \"arty program\"): Mr Mackenzie what artists have impressed you most since you've been in England? (Barry's response)Flamin' bull-artists!<br /><br />(while chatting up a naive young pom girl): Mr Mackenzie, I suppose you have hordes of Aboriginal servants back in Australia? (Barry's response) Abos? I've never seen an Abo in me life. Mum does most of the solid yacca (ie hard work) round our place.<br /><br />This is just a taste of the hilarious farce of this bonser Aussie flick. If you can get a copy of it, watch and enjoy."
]

vec_our_reviews =
  our_reviews
  |> IMDBReviews.preproc_reviews(w2v)

IMDBReviews.test_model(model, final_params, vec_our_reviews)
