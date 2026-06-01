defmodule CiPhoenixDemoWeb.Router do
  use CiPhoenixDemoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CiPhoenixDemoWeb do
    pipe_through :api
  end
end
