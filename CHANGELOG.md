# Changelog
All notable changes to the tool_name Docker file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---
## Unreleased
### Added
- Add custom `battenberg_wgs.R`

### Removed
- Remove `modify_reference_path.sh`

## [2.2.9] - 2023-06-27 [YANKED]
### Added
- Add `modify_reference_path.sh`
- Add GRCh37 and GRCh38 resource paths to `README.md`

### Changed
- Release `docker-Battenberg v2.2.9`
- Update Battenberg `v2.2.9` in Dockerfile
- Reconfigure Dockerfile
- Standardize Battenberg resource files
- Standardize the `docker-Battenberg` repo
- Rename `master` to `main` branch

### Removed
- Remove redundant files

---

## [aa14170714] - 2023-02-18
### Added
- Dockerfile based on `Wedge-lab/battenberg@aa14170714` dev branch

### Changed
- Modify version of `battenberg_wgs.R` to allow mounting of the GRCh38 reference files for Battenberg
