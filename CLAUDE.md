# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

University final project for a databases course: a PostgreSQL schema for a retail chain (database name `supermercado`), loaded with the Kaggle "Sample - Superstore" dataset re-skinned as Colombian data. Everything (table/column names, comments, error messages, docs) is in Spanish; keep new work in Spanish and follow the existing naming (`id_<tabla>`, `nombre_<x>`, snake_case).

The repo is a deliverable pipeline, not an application: problem statement (`formulacion_problema/`) → ER diagram (`ER/`) → relational design + normalization notes (`diseno_modelo_relacional/`) → PostgreSQL implementation (`implementar_en_postgreSQL/`). The `.drawio` files are the editable sources of the `.png` exports; if the schema changes, update the diagrams and `normalizacion.md` (which has a PK/FK table that mirrors the schema).

## Commands

No build/lint/test tooling. Workflow is:

```bash
# 1. Create schema (run against an empty `supermercado` DB)
psql -U postgres -h localhost -d supermercado -f implementar_en_postgreSQL/db/create_tables.sql

# 2. Regenerate the data script (needs pandas and the CSV at data/Sample - Superstore.csv)
python implementar_en_postgreSQL/db/generar_insert_data.py

# 3. Load data (re-runnable: it TRUNCATEs ... RESTART IDENTITY CASCADE first, inside one transaction)
psql -U postgres -h localhost -d supermercado -v ON_ERROR_STOP=1 -f implementar_en_postgreSQL/db/insert_data.sql
```

- `data/` and `.venv` are gitignored. The CSV is not in the repo; `notebooks/original_data.ipynb` downloads it with `kagglehub` and explores it.
- `insert_data.sql` (~4 MB) is generated and committed. Never edit it by hand: change `generar_insert_data.py` and regenerate. The generator uses `random.seed(42)` and `setseed(0.42)`, so output is deterministic; preserve that.
- `implementar_en_postgreSQL/queries/preguntas_negocio.sql` holds the business-question queries (currently only a stub with the first question's comment).

## Schema architecture (`create_tables.sql`)

- **Geography chain**: `pais` → `estado_departamento` → `ciudad` → `codigo_postal` (6-digit CHECK). `cliente` points to `codigo_postal`, plus `region` and `segmento` lookup tables (segmento is a table, not ENUM/CHECK, on purpose so it can change as data).
- **Client subtype pattern**: `cliente` (common fields, `tipo_cliente` NATURAL/CORPORATIVO) with 1:1 children `cliente_nat` (cédula) and `cliente_corp` (NIT). Clients are created through the view `v_clientes`, whose `INSTEAD OF INSERT` trigger (`process_insert_cliente`) inserts the parent and the right child and enforces cédula-xor-NIT. Insert clients via the view, not the base tables (examples are in comments in the SQL).
- **Sales**: `compra` (PRESENCIAL/ONLINE) → `detalle_compra` (PK compra+producto; stores `precio_unitario` and `descuento_aplicado` at time of sale) and optional `envio` (UNIQUE `id_compra`). `producto` → `subcategoria` → `categoria`. `inventario` is PK (producto, sucursal). `sucursal.tipo` is TIENDA or BODEGA.
- **Business rules enforced by triggers** (numbered in the SQL comments, from the problem statement PDF): Regla 12 `validar_sucursal_compra` (ONLINE purchases must be at a BODEGA, PRESENCIAL at a TIENDA) and Regla 1 `validar_envio_compra` (only ONLINE purchases may have an `envio`). Regla 7 (one postal code per client) is satisfied by `cliente.id_codigo`. Add new rules the same way (function + `BEFORE` trigger) and reference the rule number.
- All PKs are `GENERATED ALWAYS AS IDENTITY`; all FKs use `ON UPDATE CASCADE ON DELETE RESTRICT` (except the client-subtype FKs, which cascade delete). Do not insert explicit ids.

## How the data generator maps the CSV (`generar_insert_data.py`)

The CSV has no schema-equivalent for many tables, so the script simulates them; keep these mappings consistent when editing either side:

- US geography is replaced by Colombia: each US Region → a Colombian region, states/cities/postal codes rotated onto departments/municipios, postal code = DANE department prefix + 4-digit sequence.
- CSV ids (Row ID, Order ID, Customer ID, Product ID) are never stored. FKs are resolved with natural-key subqueries (`buscar_id`) and `currval('compra_id_compra_seq')` immediately after inserting each compra (so statement order matters).
- Segment `Corporate` → CORPORATIVO client (simulated NIT/razón social), others → NATURAL (simulated cédula). One postal code per client (most frequent address in the CSV).
- Channel is simulated (40 % ONLINE): ONLINE → the client region's BODEGA + an `envio` row; PRESENCIAL → a TIENDA in that region (so the data satisfies reglas 1 and 12). `sucursal` (3 tiendas + 1 bodega per region) and `inventario` are fully simulated.
- Products are unique by name (CSV reuses Product IDs for different names); duplicate order lines for the same product are merged to fit the `detalle_compra` PK.
