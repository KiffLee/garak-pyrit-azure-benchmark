# LLM security benchmark codebase

Ez a mappa a szakdolgozati benchmark futtatásához használt kódbázist tartalmazza. A cél nem egy általános benchmark keretrendszer létrehozása, hanem egy egyszerű, fájlalapú konfigurációval működő, Docker-first és bash-first mérési környezet bemutatása.

## Tartalom

```text
configs/        Benchmark konfigurációk és modellprofilok
docker/         Docker image definíciók a konténeres futtatáshoz
scripts/        Garak, PyRIT és report scriptek
results/        Az összesítő scriptek által létrehozott report fájlok másolata
```

## Konfigurációk

A `configs/benchmark` mappa a közös benchmark beállításokat tartalmazza. A `matrix.yaml` a dolgozatban vizsgált modellek és profilok áttekintésére szolgál. A `system-prompts` almappa tartalmazza a Garak mérésekben használt rendszerutasításokat.

A `configs/garak` mappa a Garak futtatásához szükséges beállításokat tartalmazza. A `models` almappában modellenként külön `.env` fájl szerepel, a `suites` almappában pedig a használt Garak suite listák találhatók.

A `configs/pyrit` mappa a PyRIT futtatásához szükséges konfigurációkat tartalmazza. A `pyrit.yaml` a PyRIT benchmark felépítését írja le, a `models` almappa pedig a modellkapcsolati beállításokat tartalmazza.

Mivel ez egy Publikus repository csak sablonos konfiguráció került ide. A valódi `.env` fájlok helyett `.env.template` fájlokat töltöttem fel, mert a modell endpointok, API kulcsok, tenant azonosítók és a service principal érzékeny adatok.

## Docker

A `docker/garak` mappa a Garak futtatásához használt Docker image definícióját tartalmazza. A benchmark célja az volt, hogy a külső teszteszközök reprodukálható konténeres környezetben fussanak, és ne a lokális Python környezet állapotától függjenek.

A Garak image építése:

```bash
bash scripts/garak/build_image.sh
```

A PyRIT image építése:

```bash
bash scripts/pyrit/build_image.sh
```

## Garak futtatás

A Garak mérések a system prompt profilok összehasonlítására szolgálnak. A guardrail beállítás ezekben a futásokban kontrollált körülményként szerepel, a dolgozatban használt éles Garak futások `guardrail_defaultV2` profillal készültek.

Példa direct safety futásra:

```bash
bash scripts/garak/run_matrix_for_current_azure_config.sh \
  --suite-file configs/garak/suites/foundry-01-direct-safety.txt \
  --system-prompt-profile system_security_hardened_no_code \
  --guardrail-profile guardrail_defaultV2
```

Példa indirect XPIA futásra:

```bash
bash scripts/garak/run_matrix_for_current_azure_config.sh \
  --suite-file configs/garak/suites/foundry-02-indirect-xpia.txt \
  --system-prompt-profile system_baseline_minimal \
  --guardrail-profile guardrail_defaultV2
```

A matrix script ugyanazzal a timestamp értékkel futtatja a négy modellt. Ez biztosítja, hogy az azonos konfigurációval, de eltérő modellel készült futások később egy csoportként összehasonlíthatók legyenek.

## PyRIT futtatás

A PyRIT mérések a guardrail beállítások összehasonlítására szolgálnak. A benchmark minden modellen két Azure Foundry guardrail profilt vizsgál.

DefaultV2 profil:

```bash
bash scripts/pyrit/run_matrix_for_current_azure_config.sh \
  --mode final \
  --guardrail-profile guardrail_defaultV2 \
  --guardrail-policy-name defaultV2
```

Szigorított profil:

```bash
bash scripts/pyrit/run_matrix_for_current_azure_config.sh \
  --mode final \
  --guardrail-profile guardrail_strict \
  --guardrail-policy-name strict
```

A PyRIT futások nem használnak külön system prompt profilt. Ez szándékos tervezési döntés, mert így a mérés fő változója a guardrail beállítás marad.

## Eredmények összesítése

A Garak összesítő scriptek a `scripts/report/garak_system_prompt` mappában találhatók. Ezek a nyers Garak futásokból CSV összesítéseket és egy rövid markdown összefoglalót készítenek.

```bash
bash scripts/report/garak_system_prompt/build.sh
```

A PyRIT összesítő script:

```bash
python3 scripts/report/export_pyrit_guardrail_summary.py
```

## Report fájlok

A `results/reports` mappában található fájlok:

```text
reports/garak_system_prompt/run_summary.csv
reports/garak_system_prompt/system_prompt_comparison.csv
reports/garak_system_prompt/probe_summary.csv
reports/garak_system_prompt/summary_notes.md
reports/pyrit_guardrail_summary.csv
```

A Garak `run_summary.csv` egy futást egy sorban ír le. A `system_prompt_comparison.csv` a system prompt profilok összehasonlítását tartalmazza. A `probe_summary.csv` probe szintű bontást ad. A `summary_notes.md` rövid emberi olvasásra szánt magyarázatot készít a Garak report fájlokhoz.

A PyRIT `pyrit_guardrail_summary.csv` a kiválasztott végleges PyRIT futásokból készített guardrail összehasonlító táblázat.

## Fontos korlátok

Ez a kódbázis nem általános célú benchmark platform. A scriptek a dolgozatban használt konkrét futtatási módokra készültek.

Az Azure Foundry deploymenteket, guardrail profilokat és kvótákat a futtatás előtt kézzel kell beállítani. A repository nem tartalmaz Azure deployment automatizmust és nem módosít guardrail beállításokat.

A nyers mérési eredmények nagy méretűek, ezért csak a template konfigurációkat és az összesített reportokat töltöttem fel.
