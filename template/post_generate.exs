# Post-generation fixes that make a freshly generated app pass `mix ci`.
#
# Run from the generated project's root:
#
#     mix run --no-start path/to/post_generate.exs
#
# Edits go through Igniter, so they work on the AST rather than on text.

defmodule PostGenerate.SortAliases do
  @moduledoc false
  # Credo --strict (Credo.Check.Readability.AliasOrder) requires consecutive
  # aliases to be sorted, and the Phoenix generator does not always do that.

  alias Sourceror.Zipper

  def update(zipper) do
    {:ok,
     Zipper.traverse(zipper, fn
       %Zipper{node: {:__block__, meta, exprs}} = z when is_list(exprs) ->
         sorted = sort_runs(exprs)
         if sorted == exprs, do: z, else: Zipper.replace(z, {:__block__, meta, sorted})

       z ->
         z
     end)}
  end

  defp sort_runs(exprs) do
    exprs
    |> Enum.chunk_by(&single_alias?/1)
    |> Enum.flat_map(fn [first | _] = run ->
      if single_alias?(first), do: sort_run(run), else: run
    end)
  end

  defp single_alias?({:alias, _, [{:__aliases__, _, _}]}), do: true
  defp single_alias?(_), do: false

  defp sort_run([first | _] = run) do
    case Enum.sort_by(run, &sort_key/1) do
      ^run ->
        run

      # The first alias's leading comment describes the whole group, so it
      # stays at the top of the group.
      [new_first | rest] ->
        rest = Enum.map(rest, &if(&1 == first, do: put_comments(&1, []), else: &1))
        [put_comments(new_first, comments(first) ++ own_comments(new_first, first)) | rest]
    end
  end

  defp own_comments(node, first) when node == first, do: []
  defp own_comments(node, _first), do: comments(node)

  defp sort_key({:alias, _, [aliases]}), do: aliases |> Macro.to_string() |> String.downcase()

  defp comments({_, meta, _}), do: Keyword.get(meta, :leading_comments, [])

  defp put_comments({form, meta, args}, comments),
    do: {form, Keyword.put(meta, :leading_comments, comments), args}
end

# `mix run --no-start` keeps the app (and its Repo) down, so start only Igniter.
{:ok, _} = Application.ensure_all_started(:igniter)

igniter = Igniter.new()
app = Igniter.Project.Application.app_name(igniter)
{igniter, repos} = Igniter.Libs.Ecto.list_repos(igniter)

# Let dev/test reach a Postgres on a non-default host port (see compose.yaml).
port = Sourceror.parse_string!(~s|String.to_integer(System.get_env("POSTGRES_PORT", "5432"))|)

igniter =
  for repo <- repos, file <- ["dev.exs", "test.exs"], reduce: igniter do
    igniter -> Igniter.Project.Config.configure(igniter, file, app, [repo, :port], {:code, port})
  end

# Not Igniter.update_all_elixir_files/2: it is a no-op once list_repos/1 has
# already loaded every file.
igniter
|> Igniter.update_glob("{lib,test,config}/**/*.{ex,exs}", &PostGenerate.SortAliases.update/1)
|> Igniter.do_or_dry_run(yes: true, title: "Template post-generation fixes")
