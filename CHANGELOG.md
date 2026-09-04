# Changelog

## [Unreleased]

### Fixed

- The binary no longer carries a path into the machine that built it (the
  terminfo directory of the build, which does not exist on your computer).

### Changed

- Built by the same compiler as the rest of the catalog. The binary grew from
  1.84 MB to 1.96 MB. Checked on Linux x86_64 and arm64: creating a session,
  listing it and killing the server all work.
