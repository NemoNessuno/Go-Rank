# Score estimator reference fixtures

This folder is intended to mirror the upstream repository's `test_games` directory.

The upstream project is:
https://github.com/online-go/score-estimator

The categories represented here are:
- easy
- mid
- hard
- no_removals
- patterns
- really_hard

Copy the matching `.game` fixture files from the upstream repository into each category folder, and the GdUnit suite in `ScoreEstimatorReferenceTests.gd` will validate that all of them parse as legal Go board positions.
