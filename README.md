# OpenELIS Global registered in the GOFR facility registry

OpenELIS Global (the [openelis-docker](https://github.com/DIGI-UW/openelis-docker) stack) with
[GOFR](https://github.com/intrahealth/gofr), the Global Open Facility Registry. One command starts both.
OpenELIS registers its laboratory in GOFR as an IHE mCSD facility (an Organization and a Location with
the laboratory's coordinates), and the laboratory appears on GOFR's facility list and map.

Point more OpenELIS instances at the same GOFR and each one registers itself: GOFR becomes the list and
map of every laboratory running OpenELIS.

Guide: [Facility Registry registration (GOFR)](https://uwdigi.atlassian.net/wiki/spaces/oeg/pages/1778090416)
(for the opposite direction, OpenELIS importing its facility list from GOFR, see
[openelis-gofr](https://github.com/DIGI-UW/openelis-gofr)).

Requires an OpenELIS image with facility registration ([OpenELIS-Global-2 #5041](https://github.com/DIGI-UW/OpenELIS-Global-2/pull/5041), merged): `develop` now, then the next release.

## Start

```bash
docker compose up -d
```

The first start takes a few minutes. Then open:

| Service | URL | User : password |
|---|---|---|
| OpenELIS | <https://localhost> | `admin` : `adminADMIN!` (from `secrets/initial-admin-password`) |
| GOFR | <http://localhost:4000> | `root@gofr.org` : `gofr` |

About a minute after OpenELIS is up, *Kampala Central Laboratory* is in GOFR: counted in **Total
Facilities** and pinned on the map on GOFR's Home page, and listed under **Facility Registry > Search >
Search Facility**. In OpenELIS, **Admin > General Configurations > Site Information**
shows the **Facility location** card: the mode, the coordinates and the last registration.

## What runs

| Service | Image | Purpose |
|---|---|---|
| OpenELIS services | `itechuw/openelis-global-2*` at `OE_IMAGE_TAG` (`develop` until a release includes facility registration), as in [openelis-docker](https://github.com/DIGI-UW/openelis-docker) | OpenELIS, its database, FHIR server, proxy, analyser Bridge |
| `gofr` | `intrahealth/gofr:7e892dd6` | GOFR app, UI and FHIR API on port 4000 |
| `gofr-fhir` | `hapiproject/hapi:v5.5.2` | Partitioned HAPI FHIR store behind GOFR (not published) |
| `gofr-hapi-cli` | `intrahealth/hapi-fhir-cli:latest` | One-shot upload of the FHIR definitions GOFR needs |
| `gofr-redis` | `redis:7.2-alpine` | GOFR cache |
| `gofr-proxy` (optional) | `nginx:1.27-alpine` | HTTPS in front of GOFR on port 4443 |

## How it is wired

`configs/properties/common.properties`:

```properties
org.openelisglobal.facility.facilityregistry=http://gofr:4000/fhir/DEFAULT
org.openelisglobal.facility.auth=token
org.openelisglobal.facility.authurl=http://gofr:4000/auth/token
org.openelisglobal.facility.username=root@gofr.org
org.openelisglobal.facility.password=gofr
org.openelisglobal.facility.autolocation=false
org.openelisglobal.facility.latitude=0.3476
org.openelisglobal.facility.longitude=32.5825
org.openelisglobal.facility.id=OE-LAB-KLA
```

- `facilityregistry` is the registry's FHIR base URL. Empty turns registration off.
- `auth`: `token` (GOFR: a bearer token from `authurl` with `username` and `password`), `basic`, or empty
  for none.
- The facility name is the OpenELIS banner heading, set here by `localization.en.BANNER_TEXT` in
  `configs/properties/SystemConfiguration.properties`. OpenELIS applies that file at every start, so
  rename the laboratory there (a change made only in Site Information is registered too, but the file
  sets the name back at the next start). `facility.id` and the address (`facility.country`, `state`,
  `district`, `city`) become the facility's identifier and address in GOFR.
- OpenELIS registers about 20 seconds after it starts and checks every 5 minutes: it retries until GOFR
  accepts, and registers again when the name or the coordinates have changed. Each registration is two
  PUTs with fixed ids, so it never creates duplicates.

### Coordinates: manual or automatic

`org.openelisglobal.facility.autolocation` switches the mode:

- `false` (manual, this setup's default): the coordinates are `facility.latitude` and
  `facility.longitude`. Without both, the facility is registered without a position and is not on the
  map.
- `true` (automatic): the latitude and longitude properties are ignored. At start OpenELIS looks up its
  public IP address with GeoJS (`https://get.geojs.io/v1/ip/geo.json`, city-level accuracy; another
  service that answers `latitude` and `longitude` can be set in
  `org.openelisglobal.facility.autolocation.url`). Until a browser position is stored, an administrator
  who signs in is asked once in each browser to share the device's location; if they allow it, that
  position replaces the IP one and OpenELIS registers again. **Use this device's location** on the
  Facility location card does the same later. Browsers share a location only over HTTPS. When the
  lookup fails (no internet access yet), the facility is registered without a position (not on the map)
  and OpenELIS tries the lookup again at every check until it answers or an administrator shares a
  browser position.

The facility's own row under **Admin > Locations** shows the position read-only: it is set only through
these properties or the Facility location card.

After changing a property, run `docker compose up -d --force-recreate oe.openelis.org`.

## The registered resources

```json
{ "resourceType": "Location", "id": "<fixed uuid>",
  "meta": { "profile": [ "http://ihe.net/fhir/StructureDefinition/IHE.mCSD.FacilityLocation" ] },
  "status": "active", "name": "Kampala Central Laboratory",
  "identifier": [ { "system": "http://openelis-global.org/facility_id", "value": "OE-LAB-KLA" } ],
  "type": [
    { "coding": [ { "system": "http://terminology.hl7.org/CodeSystem/v3-RoleCode", "code": "HLAB", "display": "hospital laboratory" } ] },
    { "coding": [ { "system": "urn:ietf:rfc:3986", "code": "urn:ihe:iti:mcsd:2019:facility" } ] } ],
  "physicalType": { "coding": [ { "system": "http://terminology.hl7.org/CodeSystem/location-physical-type", "code": "bu" } ] },
  "position": { "longitude": 32.5825, "latitude": 0.3476 },
  "managingOrganization": { "reference": "Organization/<facility uuid>" } }
```

The Organization has the profile `IHE.mCSD.FacilityOrganization`, the same name, identifier, address and
types. This is the shape GOFR itself saves when a facility is added in its UI; GOFR lists and maps only
Locations with the `urn:ihe:iti:mcsd:2019:facility` type. `org.openelisglobal.facility.type` changes the
first type code (default `HLAB`).

## For production

- `.env` and `secrets/initial-admin-password` hold demo values so that the setup starts as is. Set private
  values before the first start (see the comments in `.env`); the database and initial administrator
  passwords are taken only at the first start.
- Change the GOFR account password in GOFR (account menu), set it in
  `org.openelisglobal.facility.password`, and recreate `oe.openelis.org`. A dedicated GOFR account for
  the laboratories is better than the root one.
- Set the laboratory's own name, id, address and coordinates (or `autolocation=true`).
- HTTPS for GOFR: `scripts/make-cert.sh gofr.example.org` (writes `certs/gofr.crt` and `certs/gofr.key`),
  remove the `#` in front of `COMPOSE_PROFILES=https` in `.env`, run `docker compose up -d`, and import
  `certs/gofr.crt` into the OpenELIS truststore.
- An OpenELIS installed elsewhere registers in this GOFR with the same properties and GOFR's address as
  seen from that server.
- Backups, upgrades and certificates for OpenELIS work as in
  [openelis-docker](https://github.com/DIGI-UW/openelis-docker#readme).
