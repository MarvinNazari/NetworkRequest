# Contributing

Thanks for your interest in `NetworkRequest`. Issues, discussions, and pull
requests are all welcome.

## Development

Clone, build, and test:

```sh
git clone https://github.com/MarvinNazari/NetworkRequest
cd NetworkRequest
swift build
swift test
```

The package targets Swift 6.2 (Xcode 17+) and builds cleanly under the
Swift 6 language mode. Please make sure your changes also build without
concurrency warnings.

## Style

- Match the formatting of the surrounding code.
- Add `///` documentation comments to every new public symbol.
- Prefer adding a focused test in `Tests/NetworkRequestTests/` to
  demonstrate any new behavior or to lock in a bug fix.

## Pull requests

- Branch from `main`.
- Keep changes focused — one logical change per PR makes review easier.
- Update `CHANGELOG.md` under an `## [Unreleased]` heading when your
  change affects public behavior.
- Make sure CI is green before requesting review.

## Reporting issues

Please open an issue on GitHub and include:

- The Swift toolchain and platform you're on.
- A minimal code sample that reproduces the problem.
- The behavior you expected vs. what you saw.
