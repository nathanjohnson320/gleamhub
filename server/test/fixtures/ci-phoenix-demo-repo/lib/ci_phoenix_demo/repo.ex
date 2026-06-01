defmodule CiPhoenixDemo.Repo do
  use Ecto.Repo,
    otp_app: :ci_phoenix_demo,
    adapter: Ecto.Adapters.Postgres
end
