defmodule Protohackex.NeedForLessSpeed.SpeedChecker do
  @moduledoc """
  Checks for speed violations on a single road with 2 or more cameras.
  """

  @tolerance_mph 0.5

  @type plate :: String.t()
  @type camera_id :: any()
  @type camera_road_offset :: integer()
  @typep observation :: %{
           camera_id: camera_id(),
           timestamp: non_neg_integer()
         }

  @type t :: %__MODULE__{
          road: integer() | nil,
          speed_limit_mph: integer() | nil,
          camera_positions: %{camera_id() => camera_road_offset()},
          observations: %{
            plate() => [observation()]
          }
        }

  defstruct road: nil,
            speed_limit_mph: nil,
            camera_positions: %{},
            # Observations are kept sorted by timestamp to allow for fast lookup.
            observations: %{}

  def add_camera(%__MODULE__{} = checker, road, camera_id, camera_road_offset, speed_limit_mph) do
    new_cameras = Map.put(checker.camera_positions, camera_id, camera_road_offset)

    %{checker | road: road, speed_limit_mph: speed_limit_mph, camera_positions: new_cameras}
  end

  def add_observation(%__MODULE__{} = checker, camera_id, plate, timestamp) do
    checker =
      add_observation_in_order(checker, plate, %{camera_id: camera_id, timestamp: timestamp})

    detect_violations(checker, plate, timestamp)
  end

  defp add_observation_in_order(%__MODULE__{} = checker, plate, observation) do
    observations = Map.put_new(checker.observations, plate, [])

    plate_observations =
      [observation | observations[plate]]
      |> Enum.sort_by(& &1.timestamp)

    observations = Map.put(observations, plate, plate_observations)

    %{checker | observations: observations}
  end

  defp detect_violations(%__MODULE__{} = checker, plate, timestamp) do
    new_observation_at =
      Enum.find_index(checker.observations[plate], &(&1.timestamp == timestamp))

    observation_before = get_previous_observation(checker.observations[plate], new_observation_at)
    new_observation = Enum.at(checker.observations[plate], new_observation_at)
    observation_after = Enum.at(checker.observations[plate], new_observation_at + 1)

    violations =
      [
        detect_violation(checker, plate, observation_before, new_observation),
        detect_violation(checker, plate, new_observation, observation_after)
      ]
      |> Enum.reject(&is_nil/1)

    {checker, violations}
  end

  defp get_previous_observation(observations, from_position) do
    # `Enum.at/2` handles negative indices with modular arithmetic
    # so `observations[-1]` would return the wrong observation.
    case from_position do
      0 -> nil
      _ -> Enum.at(observations, from_position - 1)
    end
  end

  defp detect_violation(_checker, _plate, _earlier_observation, nil), do: nil
  defp detect_violation(_checker, _plate, nil, _later_observation), do: nil

  defp detect_violation(%__MODULE__{} = checker, plate, earlier_observation, later_observation) do
    distance_travelled_miles =
      checker.camera_positions[later_observation.camera_id] -
        checker.camera_positions[earlier_observation.camera_id]

    time_elapsed_sec = later_observation.timestamp - earlier_observation.timestamp

    speed_mph = distance_travelled_miles / time_elapsed_sec * 3600.0

    if speed_mph >= checker.speed_limit_mph + @tolerance_mph do
      %{
        road: checker.road,
        plate: plate,
        mile1: checker.camera_positions[earlier_observation.camera_id],
        timestamp1: earlier_observation.timestamp,
        mile2: checker.camera_positions[later_observation.camera_id],
        timestamp2: later_observation.timestamp,
        speed_mph: trunc(speed_mph)
      }
    end
  end
end
