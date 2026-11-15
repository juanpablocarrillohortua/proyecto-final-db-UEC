# Análisis de la consulta 1

Este corto txt mustra los analisis de la siguiente consulta:

## Consulta analizada

```sql
SELECT
    EXTRACT(YEAR FROM c.fecha_hora)::INT AS anio,
    EXTRACT(MONTH FROM c.fecha_hora)::INT AS mes,
    ROUND(SUM(CASE
                WHEN l.utilidad > 0 THEN l.utilidad
                ELSE 0 END), 2) AS ganancias,
    ROUND(SUM(CASE
                WHEN l.utilidad < 0 THEN l.utilidad
                ELSE 0 END), 2) AS perdidas,
    ROUND(SUM(l.utilidad), 2) AS utilidad_neta
FROM v_lineas_venta l
JOIN compra c ON c.id_compra = l.id_compra
GROUP BY anio, mes
HAVING SUM(l.venta) > 0
ORDER BY anio, mes;
```

## Plan sin optimizar

Primero la salida del analisis de la consulta sin optimizar:

```text
                                                                   QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=2102.04..2106.20 rows=1663 width=104) (actual time=60.908..60.916 rows=48.00 loops=1)
   Sort Key: ((EXTRACT(year FROM c.fecha_hora))::integer), ((EXTRACT(month FROM c.fecha_hora))::integer)
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=142
   ->  HashAggregate  (cost=1871.70..2013.07 rows=1663 width=104) (actual time=60.808..60.893 rows=48.00 loops=1)
         Group Key: (EXTRACT(year FROM c.fecha_hora))::integer, (EXTRACT(month FROM c.fecha_hora))::integer
         Filter: (sum((((d.cantidad)::numeric * d.precio_unitario) * ('1'::numeric - (d.descuento_aplicado / '100'::numeric)))) > '0'::numeric)
         Batches: 1  Memory Usage: 217kB
         Buffers: shared hit=142
         ->  Hash Join  (cost=222.33..548.55 rows=9986 width=28) (actual time=2.281..18.512 rows=9986.00 loops=1)
               Hash Cond: (d.id_compra = c.id_compra)
               Buffers: shared hit=142
               ->  Hash Join  (cost=64.62..264.75 rows=9986 width=28) (actual time=0.628..6.582 rows=9986.00 loops=1)
                     Hash Cond: (d.id_producto = p.id_producto)
                     Buffers: shared hit=97
                     ->  Seq Scan on detalle_compra d  (cost=0.00..173.86 rows=9986 width=30) (actual time=0.012..0.946 rows=9986.00 loops=1)
                           Buffers: shared hit=74
                     ->  Hash  (cost=41.50..41.50 rows=1850 width=14) (actual time=0.607..0.607 rows=1850.00 loops=1)
                           Buckets: 2048  Batches: 1  Memory Usage: 103kB
                           Buffers: shared hit=23
                           ->  Seq Scan on producto p  (cost=0.00..41.50 rows=1850 width=14) (actual time=0.007..0.279 rows=1850.00 loops=1)
                                 Buffers: shared hit=23
               ->  Hash  (cost=95.09..95.09 rows=5009 width=16) (actual time=1.618..1.622 rows=5009.00 loops=1)
                     Buckets: 8192  Batches: 1  Memory Usage: 299kB
                     Buffers: shared hit=45
                     ->  Seq Scan on compra c  (cost=0.00..95.09 rows=5009 width=16) (actual time=0.006..0.684 rows=5009.00 loops=1)
                           Buffers: shared hit=45
 Planning:
   Buffers: shared hit=18
 Planning Time: 0.678 ms
 Execution Time: 61.135 ms
(31 rows)
```

Este rendimiento posiblemente se deba a que no habia ninguna clase de indice en la tabla original.

## Plan con índices

Ahora optimizada por la inclusion del indice

```sql
CREATE INDEX idx_detalle_compra_covering
ON detalle_compra (id_compra, id_producto)
INCLUDE (cantidad, precio_unitario, descuento_aplicado);
```

```text
                                                                   QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=2102.04..2106.20 rows=1663 width=104) (actual time=48.413..48.421 rows=48.00 loops=1)
   Sort Key: ((EXTRACT(year FROM c.fecha_hora))::integer), ((EXTRACT(month FROM c.fecha_hora))::integer)
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=142
   ->  HashAggregate  (cost=1871.70..2013.07 rows=1663 width=104) (actual time=48.306..48.397 rows=48.00 loops=1)
         Group Key: (EXTRACT(year FROM c.fecha_hora))::integer, (EXTRACT(month FROM c.fecha_hora))::integer
         Filter: (sum((((d.cantidad)::numeric * d.precio_unitario) * ('1'::numeric - (d.descuento_aplicado / '100'::numeric)))) > '0'::numeric)
         Batches: 1  Memory Usage: 217kB
         Buffers: shared hit=142
         ->  Hash Join  (cost=222.33..548.55 rows=9986 width=28) (actual time=2.036..14.988 rows=9986.00 loops=1)
               Hash Cond: (d.id_compra = c.id_compra)
               Buffers: shared hit=142
               ->  Hash Join  (cost=64.62..264.75 rows=9986 width=28) (actual time=0.652..5.421 rows=9986.00 loops=1)
                     Hash Cond: (d.id_producto = p.id_producto)
                     Buffers: shared hit=97
                     ->  Seq Scan on detalle_compra d  (cost=0.00..173.86 rows=9986 width=30) (actual time=0.015..0.773 rows=9986.00 loops=1)
                           Buffers: shared hit=74
                     ->  Hash  (cost=41.50..41.50 rows=1850 width=14) (actual time=0.629..0.629 rows=1850.00 loops=1)
                           Buckets: 2048  Batches: 1  Memory Usage: 103kB
                           Buffers: shared hit=23
                           ->  Seq Scan on producto p  (cost=0.00..41.50 rows=1850 width=14) (actual time=0.009..0.288 rows=1850.00 loops=1)
                                 Buffers: shared hit=23
               ->  Hash  (cost=95.09..95.09 rows=5009 width=16) (actual time=1.336..1.340 rows=5009.00 loops=1)
                     Buckets: 8192  Batches: 1  Memory Usage: 299kB
                     Buffers: shared hit=45
                     ->  Seq Scan on compra c  (cost=0.00..95.09 rows=5009 width=16) (actual time=0.009..0.569 rows=5009.00 loops=1)
                           Buffers: shared hit=45
 Planning:
   Buffers: shared hit=52 read=3
 Planning Time: 0.846 ms
 Execution Time: 48.684 ms
(31 rows)
```

## Explicación

Aca el plan de ejecucion es exactamente igual (a pesar del indice), esto se debe a que para el motor
de optimizacion de postgreSQL es mucho mas economico recorrer todas las filas en
lugar de usar indices, es posible que la utilidad de los indices se vea reflejado
de manera practica si la tabla alamacenase una cantidad mucho mayor de datos, es
decir el indice que se acaba de definir actua como un seguro o una preparacion
para que el rendimiento no colapse cuando la base de datos escale y almacene
mucha mas informacion. Ademas es plausible que incluso con muchos datos el plan
del optimizador no cambie, ya que no hay una clausula WHERE en la consulta, con lo
cual no aprovecha en gran medida la estrucutra de B-Trees que esta por
debajo de esos indices. Ya que un indice indica que deberia filtrar el WHERE de
manera preliminar antes de cualquier otro proceso, sin un estos no esta esa
necesidad de prefiltrado y de ahi que no se vea el cambio.
