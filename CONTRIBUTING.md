# Contributing to Readability

Thank you for your interest in contributing to this Dart port of Mozilla's Readability.js!

## Getting Started

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) 3.0 or higher
- [Node.js](https://nodejs.org/) (for E2E tests)
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/mortezaPRK/readability.git
cd readability

# Install dependencies
make get

# Run tests to verify setup
make test-unit
```

## Development Workflow

### Running Tests

```bash
# Run unit tests
make test-unit

# Run E2E tests (requires Node.js)
make test-e2e

# Run all checks (lint + unit tests)
make ci
```

### Code Quality

```bash
# Check formatting and run analyzer
make lint

# Auto-fix issues and format code
make fix
```

### Building

```bash
# Build CLI binary
make build-cli

# Build JavaScript bundle
make build-js

# Build all artifacts
make build-all
```

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `make lint` before committing
- Keep changes focused and atomic

## Pull Request Process

1. **Fork** the repository
2. **Create a branch** for your feature or fix
3. **Make changes** and add tests if applicable
4. **Run checks**: `make ci`
5. **Push** your branch and open a PR

### PR Guidelines

- Keep PRs focused on a single change
- Write clear commit messages
- Update documentation if needed
- Ensure all CI checks pass

## Mozilla Sync

This library aims to maintain compatibility with [Mozilla's Readability.js](https://github.com/mozilla/readability). When porting changes from upstream:

1. Reference the Mozilla commit hash
2. Adapt JavaScript patterns to Dart idioms
3. Ensure E2E tests pass
4. Document any intentional divergence

See `.claude/skills/mozilla-sync.md` for detailed sync guidelines.

## Testing

### Unit Tests

Located in `test/unit/`. Test individual components and edge cases.

### E2E Tests

Located in `test/e2e/`. Run against Mozilla's test suite for compatibility verification.

```bash
# This clones Mozilla's repo and runs compatibility tests
make test-e2e
```

## Project Structure

```
lib/
├── readability.dart          # Public API exports
└── src/
    ├── readability.dart      # Core algorithm
    ├── jsdom_parser.dart     # DOM parser (MPL-2.0)
    ├── readability_readerable.dart
    ├── dom_adapter.dart      # Parser abstraction
    └── adapters/             # Parser implementations

bin/
└── cli.dart                  # Command-line tool

test/
├── unit/                     # Unit tests
└── e2e/                      # End-to-end tests
```

## Questions?

- Open an [issue](https://github.com/mortezaPRK/readability/issues) for bugs or feature requests
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the same dual license as the project (Apache 2.0 / MPL 2.0).
