# Análisis de la consulta 2

Este corto txt mustra los analisis de la siguiente consulta:

## Consulta analizada

```sql
WITH ventas_por_region AS (
    SELECT
        r.id_region,
        r.nombre_region,
        SUM(dt.cantidad) AS unidades_vendidas,
        SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0) * dt.cantidad) AS total_ventas,
        SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0)) - p.precio_compra) * dt.cantidad) AS utilidad_total
    FROM region AS r
    JOIN cliente AS c ON r.id_region = c.id_region
    JOIN compra AS co ON c.id_cliente = co.id_cliente
    JOIN detalle_compra AS dt ON co.id_compra = dt.id_compra
    JOIN producto AS p ON dt.id_producto = p.id_producto
    WHERE co.fecha_hora >= '2014-01-01'  -- se agrega este where para ver como se mejoraria usando indices
        AND co.fecha_hora < '2015-02-01'
    GROUP BY r.id_region, r.nombre_region
),
promedios AS (
    SELECT
        AVG(total_ventas) AS ventas_promedio,
        SUM(utilidad_total) * 100.0 / NULLIF(SUM(total_ventas), 0) AS margen_global
    FROM ventas_por_region
)
SELECT
    v.nombre_region,
    v.unidades_vendidas,
    ROUND(v.total_ventas, 2) AS total_ventas,
    ROUND(v.utilidad_total, 2) AS utilidad_total,
    ROUND(v.utilidad_total * 100.0 / NULLIF(v.total_ventas, 0), 2) AS porcentaje_margen_utilidad,
    ROUND(p.margen_global, 2) AS margen_global,
    v.total_ventas > p.ventas_promedio
        AND v.utilidad_total * 100.0 / NULLIF(v.total_ventas, 0) < p.margen_global
        AS alto_volumen_baja_utilidad
FROM ventas_por_region AS v
CROSS JOIN promedios AS p
ORDER BY v.total_ventas DESC;
```

## Plan sin optimizar

Primero la salida del analisis de la consulta sin optimizar:

```text
                                                                                            QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=595.28..596.38 rows=440 width=315) (actual time=7.836..7.840 rows=4.00 loops=1)
   Sort Key: v.total_ventas DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=150
   CTE ventas_por_region
     ->  HashAggregate  (cost=531.93..538.53 rows=440 width=226) (actual time=7.795..7.801 rows=4.00 loops=1)
           Group Key: r.nombre_region
           Batches: 1  Memory Usage: 48kB
           Buffers: shared hit=150
           ->  Hash Join  (cost=241.91..457.68 rows=1980 width=174) (actual time=1.222..4.994 rows=2050.00 loops=1)
                 Hash Cond: (dt.id_producto = p.id_producto)
                 Buffers: shared hit=150
                 ->  Hash Join  (cost=177.29..387.85 rows=1980 width=176) (actual time=0.812..3.950 rows=2050.00 loops=1)
                       Hash Cond: (c.id_region = r.id_region)
                       Buffers: shared hit=127
                       ->  Hash Join  (cost=157.39..362.71 rows=1980 width=30) (actual time=0.797..3.430 rows=2050.00 loops=1)
                             Hash Cond: (co.id_cliente = c.id_cliente)
                             Buffers: shared hit=126
                             ->  Hash Join  (cost=132.55..332.64 rows=1980 width=30) (actual time=0.627..2.633 rows=2050.00 loops=1)
                                   Hash Cond: (dt.id_compra = co.id_compra)
                                   Buffers: shared hit=119
                                   ->  Seq Scan on detalle_compra dt  (cost=0.00..173.86 rows=9986 width=30) (actual time=0.006..0.609 rows=9986.00 loops=1)
                                         Buffers: shared hit=74
                                   ->  Hash  (cost=120.13..120.13 rows=993 width=16) (actual time=0.612..0.613 rows=998.00 loops=1)
                                         Buckets: 1024  Batches: 1  Memory Usage: 55kB
                                         Buffers: shared hit=45
                                         ->  Seq Scan on compra co  (cost=0.00..120.13 rows=993 width=16) (actual time=0.006..0.513 rows=998.00 loops=1)
                                               Filter: ((fecha_hora >= '2014-01-01 00:00:00-05'::timestamp with time zone) AND (fecha_hora < '2015-02-01 00:00:00-05'::timestamp with time zone))
                                               Rows Removed by Filter: 4011
                                               Buffers: shared hit=45
                             ->  Hash  (cost=14.93..14.93 rows=793 width=16) (actual time=0.166..0.166 rows=793.00 loops=1)
                                   Buckets: 1024  Batches: 1  Memory Usage: 46kB
                                   Buffers: shared hit=7
                                   ->  Seq Scan on cliente c  (cost=0.00..14.93 rows=793 width=16) (actual time=0.005..0.085 rows=793.00 loops=1)
                                         Buffers: shared hit=7
                       ->  Hash  (cost=14.40..14.40 rows=440 width=154) (actual time=0.010..0.010 rows=4.00 loops=1)
                             Buckets: 1024  Batches: 1  Memory Usage: 9kB
                             Buffers: shared hit=1
                             ->  Seq Scan on region r  (cost=0.00..14.40 rows=440 width=154) (actual time=0.006..0.007 rows=4.00 loops=1)
                                   Buffers: shared hit=1
                 ->  Hash  (cost=41.50..41.50 rows=1850 width=14) (actual time=0.404..0.404 rows=1850.00 loops=1)
                       Buckets: 2048  Batches: 1  Memory Usage: 103kB
                       Buffers: shared hit=23
                       ->  Seq Scan on producto p  (cost=0.00..41.50 rows=1850 width=14) (actual time=0.014..0.202 rows=1850.00 loops=1)
                             Buffers: shared hit=23
   ->  Nested Loop  (cost=11.01..37.44 rows=440 width=315) (actual time=7.823..7.828 rows=4.00 loops=1)
         Buffers: shared hit=150
         ->  Aggregate  (cost=11.01..11.03 rows=1 width=64) (actual time=7.817..7.818 rows=1.00 loops=1)
               Buffers: shared hit=150
               ->  CTE Scan on ventas_por_region  (cost=0.00..8.80 rows=440 width=64) (actual time=7.799..7.804 rows=4.00 loops=1)
                     Storage: Memory  Maximum Storage: 17kB
                     Buffers: shared hit=150
         ->  CTE Scan on ventas_por_region v  (cost=0.00..8.80 rows=440 width=218) (actual time=0.000..0.001 rows=4.00 loops=1)
               Storage: Memory  Maximum Storage: 17kB
 Planning:
   Buffers: shared hit=24
 Planning Time: 0.823 ms
 Execution Time: 8.038 ms
(58 rows)
```

## Plan con índices

Despues de agregar los indices:

```text
                                                                                              QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=519.43..520.53 rows=440 width=315) (actual time=10.656..10.662 rows=4.00 loops=1)
   Sort Key: v.total_ventas DESC
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=108 read=4
   CTE ventas_por_region
     ->  HashAggregate  (cost=456.07..462.67 rows=440 width=226) (actual time=10.603..10.613 rows=4.00 loops=1)
           Group Key: r.nombre_region
           Batches: 1  Memory Usage: 48kB
           Buffers: shared hit=108 read=4
           ->  Hash Join  (cost=165.95..381.75 rows=1982 width=174) (actual time=1.998..7.156 rows=2050.00 loops=1)
                 Hash Cond: (dt.id_producto = p.id_producto)
                 Buffers: shared hit=108 read=4
                 ->  Hash Join  (cost=101.33..311.91 rows=1982 width=176) (actual time=1.513..5.596 rows=2050.00 loops=1)
                       Hash Cond: (c.id_region = r.id_region)
                       Buffers: shared hit=85 read=4
                       ->  Hash Join  (cost=81.43..286.75 rows=1982 width=30) (actual time=1.467..4.906 rows=2050.00 loops=1)
                             Hash Cond: (co.id_cliente = c.id_cliente)
                             Buffers: shared hit=84 read=4
                             ->  Hash Join  (cost=56.59..256.68 rows=1982 width=30) (actual time=1.093..3.712 rows=2050.00 loops=1)
                                   Hash Cond: (dt.id_compra = co.id_compra)
                                   Buffers: shared hit=77 read=4
                                   ->  Seq Scan on detalle_compra dt  (cost=0.00..173.86 rows=9986 width=30) (actual time=0.026..0.746 rows=9986.00 loops=1)
                                         Buffers: shared hit=74
                                   ->  Hash  (cost=44.16..44.16 rows=994 width=16) (actual time=1.038..1.038 rows=998.00 loops=1)
                                         Buckets: 1024  Batches: 1  Memory Usage: 55kB
                                         Buffers: shared hit=3 read=4
                                         ->  Index Only Scan using idx_compra_fecha_cliente on compra co  (cost=0.28..44.16 rows=994 width=16) (actual time=0.043..0.658 rows=998.00 loops=1)
                                               Index Cond: ((fecha_hora >= '2014-01-01 00:00:00-05'::timestamp with time zone) AND (fecha_hora < '2015-02-01 00:00:00-05'::timestamp with time zone))
                                               Heap Fetches: 0
                                               Index Searches: 1
                                               Buffers: shared hit=3 read=4
                             ->  Hash  (cost=14.93..14.93 rows=793 width=16) (actual time=0.366..0.367 rows=793.00 loops=1)
                                   Buckets: 1024  Batches: 1  Memory Usage: 46kB
                                   Buffers: shared hit=7
                                   ->  Seq Scan on cliente c  (cost=0.00..14.93 rows=793 width=16) (actual time=0.009..0.222 rows=793.00 loops=1)
                                         Buffers: shared hit=7
                       ->  Hash  (cost=14.40..14.40 rows=440 width=154) (actual time=0.029..0.029 rows=4.00 loops=1)
                             Buckets: 1024  Batches: 1  Memory Usage: 9kB
                             Buffers: shared hit=1
                             ->  Seq Scan on region r  (cost=0.00..14.40 rows=440 width=154) (actual time=0.024..0.025 rows=4.00 loops=1)
                                   Buffers: shared hit=1
                 ->  Hash  (cost=41.50..41.50 rows=1850 width=14) (actual time=0.476..0.477 rows=1850.00 loops=1)
                       Buckets: 2048  Batches: 1  Memory Usage: 103kB
                       Buffers: shared hit=23
                       ->  Seq Scan on producto p  (cost=0.00..41.50 rows=1850 width=14) (actual time=0.022..0.260 rows=1850.00 loops=1)
                             Buffers: shared hit=23
   ->  Nested Loop  (cost=11.01..37.44 rows=440 width=315) (actual time=10.640..10.645 rows=4.00 loops=1)
         Buffers: shared hit=108 read=4
         ->  Aggregate  (cost=11.01..11.03 rows=1 width=64) (actual time=10.632..10.632 rows=1.00 loops=1)
               Buffers: shared hit=108 read=4
               ->  CTE Scan on ventas_por_region  (cost=0.00..8.80 rows=440 width=64) (actual time=10.608..10.616 rows=4.00 loops=1)
                     Storage: Memory  Maximum Storage: 17kB
                     Buffers: shared hit=108 read=4
         ->  CTE Scan on ventas_por_region v  (cost=0.00..8.80 rows=440 width=218) (actual time=0.000..0.001 rows=4.00 loops=1)
               Storage: Memory  Maximum Storage: 17kB
 Planning:
   Buffers: shared hit=233 read=2
 Planning Time: 8.481 ms
 Execution Time: 10.881 ms
(59 rows)
```

## Comparación de métricas

| Métrica | Sin índices | Con índices | Cambio / Interpretación |
| :--- | :--- | :--- | :--- |
| **Costo estimado total** | `596.38` | `520.53` | **Bajó ~13%** (el planificador prefiere el nuevo plan) |
| **Buffers leídos (total)** | `150` páginas | `112` páginas (`108 hit + 4 read`) | **Bajó 25%** (38 páginas menos de 8 KB leídas) |
| **Acceso a `compra`** | `Seq Scan` (45 buffers) | `Index Only Scan` (7 buffers, `Heap Fetches: 0`) | **Reducción del 84%** sobre el acceso a `compra` |
| **Tiempo de ejecución** | `8.038 ms` | `10.881 ms` | **Subió ~2.8 ms** por lecturas en frío desde disco (`read=4`) |

Esto supone una mejora principalmente en el acceso a compra pues al utilizar Index Only Scan se ahorra la tarea de recorrer toda la tabla, por lo tanto se hace un ahorro importante de procesamiento en ese paso, esto se ve evidenciado en la estimacion menor que realiza el optimizador despues de agregar el indice, el mayor tiempo de ejecucion no se debe a que la query se haya hecho mas lenta, solo ocurrio ya que fue necesario leer cierta informacion en disco (posiblemente no estaba cargada en RAM).
