-- The game's ability tasks as it makes them, the player's and the enemies': an ability makes its tasks as it starts.
-- Read at the next tick, a tenth of a second later at most (dynamic_fov_made.lua). The class is the engine's, the
-- parent of every ability task (Movement Tuning watches the same, seen in game).

return require("dynamic_fov_made").new("/Script/GameplayAbilities.AbilityTask")
