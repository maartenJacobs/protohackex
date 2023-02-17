defmodule Protohackex.NeedForLessSpeed.SpeedCheckerTest do
  use ExUnit.Case
  doctest Protohackex.NeedForLessSpeed.SpeedChecker
  alias Protohackex.NeedForLessSpeed.SpeedChecker

  test "detects speed violation" do
    checker =
      %SpeedChecker{}
      |> SpeedChecker.add_camera(123, 1, 8, 60)
      |> SpeedChecker.add_camera(123, 2, 9, 60)

    {checker, []} = SpeedChecker.add_observation(checker, 1, "UN1X", 0)
    {_checker, violations} = SpeedChecker.add_observation(checker, 2, "UN1X", 45)

    assert violations == [
             %{
               mile1: 8,
               mile2: 9,
               plate: "UN1X",
               timestamp1: 0,
               timestamp2: 45,
               road: 123,
               speed_mph: 80
             }
           ]
  end

  test "detects violations before and after new observation" do
    checker =
      %SpeedChecker{}
      |> SpeedChecker.add_camera(123, 1, 8, 60)
      |> SpeedChecker.add_camera(123, 2, 9, 60)
      |> SpeedChecker.add_camera(123, 3, 10, 60)

    {checker, []} = SpeedChecker.add_observation(checker, 1, "UN1X", 0)
    {checker, _violations} = SpeedChecker.add_observation(checker, 3, "UN1X", 90)
    {_checker, violations} = SpeedChecker.add_observation(checker, 2, "UN1X", 45)

    assert violations == [
             %{
               mile1: 8,
               mile2: 9,
               plate: "UN1X",
               timestamp1: 0,
               timestamp2: 45,
               road: 123,
               speed_mph: 80
             },
             %{
               mile1: 9,
               mile2: 10,
               plate: "UN1X",
               road: 123,
               speed_mph: 80,
               timestamp1: 45,
               timestamp2: 90
             }
           ]
  end

  test "reports no violation if below speed limit" do
    checker =
      %SpeedChecker{}
      |> SpeedChecker.add_camera(123, 1, 8, 60)
      |> SpeedChecker.add_camera(123, 2, 9, 60)

    {checker, []} = SpeedChecker.add_observation(checker, 1, "UN1X", 0)
    {_checker, violations} = SpeedChecker.add_observation(checker, 2, "UN1X", 65)

    assert violations == []
  end

  test "reports no violation if within tolerance" do
    checker =
      %SpeedChecker{}
      |> SpeedChecker.add_camera(123, 1, 100, 120)
      |> SpeedChecker.add_camera(123, 2, 200, 120)

    # The observations add up to 120.4mph and the tolerance is 0.5mph.
    {checker, []} = SpeedChecker.add_observation(checker, 1, "UN1X", 0)
    {_checker, violations} = SpeedChecker.add_observation(checker, 2, "UN1X", 2990)

    assert violations == []
  end
end
