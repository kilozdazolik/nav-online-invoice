# NAV XML schemas

Copies of the official XSD schemas of the NAV Online Invoice API v3.0, used to validate outgoing requests.

| File | Source | Commit |
|---|---|---|
| `invoiceApi.xsd`, `invoiceBase.xsd`, `invoiceData.xsd`, `invoiceAnnulment.xsd`, `serviceMetrics.xsd`, `LICENCE.md` | [nav-gov-hu/Online-Invoice](https://github.com/nav-gov-hu/Online-Invoice) `src/schemas/nav/gov/hu/OSA/` | `2ef626c71659a2571b1a971822b639a8466aa07e` |
| `common.xsd` | [nav-gov-hu/Common](https://github.com/nav-gov-hu/Common) `schemas/src/main/resources/xsd/hu/gov/nav/schemas/NTCA/1.0/common/` | `ab8d7887967492e5f6d6e25447be853fd767add8` (tag `common-1.0.0`) |

Downloaded on 2026-11-17.

NAV's `catalog.xml` points to `Common-1.0.RC3`, but that version lacks `RequestPageType` and `ResponsePageType`,
which `invoiceApi.xsd` uses. `common-1.0.0` is the first final 1.0 release and contains every type the API schemas
need, in the same namespace (`http://schemas.nav.gov.hu/NTCA/1.0/common`).

## Modifications

NAV's `xs:import` elements have no `schemaLocation`; NAV resolves them through an OASIS catalog, which libxml2
(Nokogiri) does not use. Each import was given a `schemaLocation` pointing to the local file. Nothing else was
changed.

## Updating

```sh
bin/dev bundle exec rake schemas:sync
```

Change the pinned commits in `rakelib/schemas.rake` first. The task prints the sha256 of each file; update the
table below.

## Checksums (after modification)

```text
985b38a680727903249202debef953273d1cfdea6c574110986de79db4c6d64e  invoiceApi.xsd
d8eaca86cfa203bc2811a5f628bb25655be4a5884f8caea68f23beabbadf1e96  invoiceBase.xsd
299ae1a1164c18be35fb82bf2c4579994b1b2bc1c5c4d3e690c3f0b6256a0ddb  invoiceData.xsd
19422aa36ae6dc3dd9f5e31bfde50f18080883cac1a6ed9c7b994d2f2c97518c  invoiceAnnulment.xsd
a3f90a3b3c8a4e5355c297b09433be1727d304b4f019be68c8a117ddfbe8a75c  serviceMetrics.xsd
0ad7a99292d9b5c967d0cf1f37ceafd9945ac456b534963c7c72a6e7bb42971c  common.xsd
ad19a86dcd93ff6e599a38c0c2b92b87935db6f2acf88bf86818d64c9414750b  LICENCE.md
```

## Licence

The schemas are © 2019 Nemzeti Adó- és Vámhivatal (Hungarian Tax Authority), released under the MIT License.
See [LICENCE.md](LICENCE.md).
