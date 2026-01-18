defmodule WhatIsMyIpTest do
  use ExUnit.Case
  doctest WhatIsMyIp

  test "greets the world" do
    assert WhatIsMyIp.hello() == :world
  end
end
