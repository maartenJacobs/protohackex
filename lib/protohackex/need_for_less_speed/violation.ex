defmodule Protohackex.NeedForLessSpeed.Violation do
  alias Protohackex.NeedForLessSpeed.Road

  @type t :: %__MODULE__{
          road: Road.road_id(),
          plate: Road.plate(),
          mile1: Road.camera_road_offset(),
          timestamp1: non_neg_integer(),
          mile2: Road.camera_road_offset(),
          timestamp2: non_neg_integer(),
          speed_mph: non_neg_integer()
        }

  defstruct [:road, :plate, :mile1, :mile2, :timestamp1, :timestamp2, :speed_mph]
end
