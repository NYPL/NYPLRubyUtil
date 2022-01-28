# Changelog

## v0.0.9
- Add generic `custom_aws_config` in `KinesisClient`

## v0.0.8
- Error logging for batched records in Kinesis Client

## v0.0.7
Add batching of records in KinesisClient

## v0.0.6
Fix bug setting token in platform_api_client

## v0.0.5
Minor cosmetic fixes

## v0.0.4
### Added deploy_helper
- Add deploy_helper

## v0.0.3
### Fixed
- Remove base64 encoding on write in the KinesisClient.
- Add UTF-8 encoding for StringIO object in NYPLAvro.

## v0.0.0

Initial version. Includes `kinesis_client`, `kms_client`, `nypl_avro`, `platform_api_client`,
`nypl_sierra_api_client`, and `nypl_log_formatter`.
