# GoRank

GoRank is a Godot 4 prototype for managing Go students and recording their games. The first loop creates a playful overworld where each student can be represented as an avatar, created in the sidebar, and selected on the map.

## Features

- Character/avatar creation for Go students
- Overworld map with interactive student cards
- 9x9 Go match board with capture logic and Ko protection
- Session tracking for wins and losses
- Save data in `user://students.json`
- Cross-platform-friendly Godot UI for desktop, mobile, and web builds

## Running the project

1. Open this folder in the Godot 4 editor.
2. Set the project root to this folder.
3. Press F5 to run the main scene.

The project is configured to start from the overworld scene at `res://scenes/Overworld.tscn`.

## First loop goals

This prototype focuses on the beginner loop:

- create avatars,
- place them in a map,
- select them,
- open a 9x9 Go board,
- record their results,
- persist the data so the students remain present between play sessions.

## 9x9 rules included

The board scene is specialized for 9x9 play and includes the following protection rules:

- stones cannot be placed on occupied intersections,
- captures are resolved by removing surrounded opponent groups,
- suicide moves are rejected,
- simple Ko detection is enforced by comparing the board position against the immediately previous legal state.

## Rules and score estimator reference

This project follows the standard Go scoring model and uses the territory / dead-stone estimation approach from the Online-Go score estimator as a reference implementation:

- https://github.com/online-go/score-estimator
- MIT licensed, used as a rules and estimation reference for territory assessment and dead-stone heuristics.

## Next milestones

- add match history screens,
- add rating ladder and tournament brackets,
- add game recording for board positions,
- add richer world interactions and quest-like activities.
