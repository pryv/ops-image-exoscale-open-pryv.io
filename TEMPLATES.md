# Registered templates

One line per template build. A template copied to other zones keeps the same ID. Since 2.0 the
template name carries no Open Pryv.io version (the release is chosen at first boot) and each release
also publishes its QCOW2 file.

The templates below are registered in the Pryv organization and stay private. The Marketplace
listing launches the public copy that Exoscale registers from the published QCOW2, under its own
ID (same checksum):

| Release | Public template ID (Exoscale) | Zones | Registered | Checksum |
|---------|-------------------------------|-------|------------|----------|
| 2.0-1 | 2864e8aa-d41d-452b-8ef0-b2877908e47c | at-vie-1, at-vie-2, bg-sof-1, ch-dk-2, ch-gva-2, de-fra-1, de-muc-1, hr-zag-1 | 2026-10-27 | `848fcb2ec07ec7c8010cfbdf839f890b` |

Private templates:

| Template name | Version | Build | Zones | Template ID | Registered | Status | QCOW2 (URL, MD5) |
|---------------|---------|-------|-------|-------------|------------|--------|------------------|
| Open Pryv.io | 2.0 | 1 | at-vie-1, at-vie-2, bg-sof-1, ch-dk-2, ch-gva-2, de-fra-1, de-muc-1, hr-zag-1 | 69c65229-bf01-475d-b81f-463630be40b3 | 2026-10-14 | released (source tag `2.0-1`) | https://sos-ch-gva-2.exo.io/pryv-marketplace-images/open-pryv.io-2.0-1.qcow2, MD5 `848fcb2ec07ec7c8010cfbdf839f890b` |
| Open Pryv.io 2.0.0-rc.43 | 2.0.0-rc.43 | 1 | at-vie-1, at-vie-2, bg-sof-1, ch-dk-2, ch-gva-2, de-fra-1, de-muc-1, hr-zag-1 | 1087c3ae-2030-4530-82f5-f394490419e0 | 2026-10-09 | released (source tag `2.0.0-rc.43-1`); Exoscale cannot copy it into the Marketplace (registered from an export URL that expired): superseded by 2.0-1 (listing live 2026-10-27); still registered because an instance runs from it, to be deleted when that instance is rebuilt | none |
| Open Pryv.io 2.0.0-rc.43 (test) | 2.0.0-rc.43 | test1 | ch-gva-2 | 0b3a8718-1df9-4a8a-b7e0-a3f526ae9b14 | 2026-10-08 | test, deleted 2026-10-08 | none |
| Open Pryv.io 2.0.0-rc.43 (test) | 2.0.0-rc.43 | test2 | ch-gva-2 | 1bda1159-366c-4cdc-9688-ac9976892392 | 2026-10-08 | test, deleted 2026-10-08 | none |
| Open Pryv.io 2.0.0-rc.43 (test) | 2.0.0-rc.43 | test3 | ch-gva-2 | 2e58d051-f9da-4ec4-a904-c780b551926e | 2026-10-08 | test, deleted 2026-10-08 | none |
| Open Pryv.io (test) | 2.0 | test1 | ch-gva-2 | 3375d3b1-2cec-44f8-853d-8dc84318954f | 2026-10-13 | test, deleted 2026-10-14 | local only, deleted |
| Open Pryv.io (test) | 2.0 | test2 | ch-gva-2 | b2624d1f-1434-406b-9b41-d8e46a600477 | 2026-10-14 | test, deleted 2026-10-14 | local only, deleted |
