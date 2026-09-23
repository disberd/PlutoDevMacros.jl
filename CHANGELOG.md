# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `@frompackage`/`@fromparent` find versioned manifests (e.g. `Manifest-v1.13.toml`), an explicit `manifest` entry in `Project.toml` and workspace manifests. The lookup uses the same rules as Julia's own package loading.

### Fixed
- Errors from `@frompackage`/`@fromparent` inside Pluto show correctly on Julia 1.13. Before this fix, a `MethodError` in `CapturedException` hid the real error.

## [0.9.2] - 2025-11-10

### Fixed
- Fixed an issue when importing from submodules of the imported package without using relative imports.
- Fixed an issue when trying to import (either directly or indirectly via `import *`) from Base or Core.

## [0.9.1] - 2025-07-14
This is the first version were the CHANGELOG was added

### Changed
- Updated compat of JuliaInterpreter to support v0.10

### Fixed
- Made the package compatible with julia 1.12