# elixir-phoenix

A generator for new Phoenix apps. Instead of a checked-in app that goes stale,
this repo holds the recipe: a pinned toolchain, one `mise` task, and the files
and fixes applied after generation. Each run pulls the latest Phoenix and
[VibeKit](https://github.com/elixir-vibe/vibe_kit).

## Requirements

- [mise](https://mise.jdx.dev)
- Docker (for the Postgres service)

## Usage

```sh
git clone git@github.com:whargrove/elixir-phoenix.git
cd elixir-phoenix
mise trust && mise install
mise run new my_app                  # creates ../my_app
mise run new my_app --path ~/code    # creates ~/code/my_app
```

Then, in the new app:

```sh
docker compose up -d --wait
mix ecto.setup
mix ci
```

If port 5432 is already taken, set `POSTGRES_PORT` (e.g. `POSTGRES_PORT=55432`)
for both `docker compose` and `mix`. The dev and test repo configs read it too.

## What `mise run new` does

1. Installs the `igniter_new` and `phx_new` Mix archives.
2. Runs `mix igniter.new <name> --with phx.new --install vibe_kit --yes`, which
   generates a default Phoenix app (Postgres, LiveView, Tailwind, esbuild) and
   applies VibeKit: a `mix ci` alias plus Credo, Dialyzer, ExDNA, ExSlop and
   Reach.
3. Writes a `mise.toml` in the app pinning the same Erlang and Elixir versions
   as this repo.
4. Copies `template/compose.yaml` (Postgres 18) into the app.
5. Runs `template/post_generate.exs`, which uses Igniter to edit the AST:
   - adds `port: POSTGRES_PORT` (default `5432`) to the dev and test Repo configs
   - sorts consecutive `alias` lines so `credo --strict` passes
6. Runs `mix format`, which also fixes generated lines that go over the limit
   when the app name is long, and commits the result on top of Igniter's
   initial commit.

The result passes `mix ci` with no changes.

## Layout

| Path | Purpose |
| --- | --- |
| `mise.toml` | Pinned Erlang/OTP and Elixir versions |
| `mise-tasks/new` | The generator task |
| `template/compose.yaml` | Postgres 18 service copied into each app |
| `template/post_generate.exs` | Igniter-based fixes run inside the new app |

## Updating

- **Toolchain:** `mise use erlang@latest elixir@latest` (pick the
  `-otp-<major>` Elixir build that matches Erlang), then commit `mise.toml`.
- **New fixes:** add them to `template/post_generate.exs` as Igniter or
  Sourceror edits rather than text substitutions. Check them by generating a
  throwaway app and running `mix ci` in it.
