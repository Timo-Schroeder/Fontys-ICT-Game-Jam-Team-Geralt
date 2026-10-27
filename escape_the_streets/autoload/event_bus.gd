extends Node
## Global signal hub (autoload "EventBus").
## Gameplay systems emit here; the rules engine, HUD and (later) audio/analytics listen.
## Keeps systems decoupled: a vehicle does not need to know that a HUD exists.

## A traffic rule was broken. `type` is a RuleBook.Violation value.
## `context` carries extra info, e.g. {"by": "auto", "position": Vector3}.
signal violation(type: int, context: Dictionary)

## Non-penalty feedback for the player, e.g. "Druk op E om op de knop te drukken".
signal hint(text: String, seconds: float)

## An emergency vehicle is on its way (true) or has gone (false).
signal emergency_state_changed(active: bool)

## Level lifecycle.
signal level_started(level: LevelData)
signal package_picked_up
signal level_finished(success: bool, stars: int)
