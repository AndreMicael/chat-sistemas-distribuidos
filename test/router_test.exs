defmodule ChatDistribuidoWeb.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test

  test "página e verificação de saúde usam recursos internos do projeto" do
    page = ChatDistribuidoWeb.Router.call(conn(:get, "/"), [])
    assert page.status == 200
    assert page.resp_body =~ "Chat Distribuído"

    health = ChatDistribuidoWeb.Router.call(conn(:get, "/health"), [])
    assert health.status == 200
    assert %{"status" => "ok", "no" => _} = Jason.decode!(health.resp_body)
  end
end
