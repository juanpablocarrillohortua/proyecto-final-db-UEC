-- Las queries seleccionadas son:

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

------------------------------------------------------------------------------

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



-- Analizar la primera query seleccionada.
EXPLAIN ANALYZE
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

-- indice propuesto

-- un indice sobre detalle_compra, este es util ya que toma los calculos de venta
-- y utilidad (realizados por v_lineas_venta) y hace que sean posibles de calcular
-- usando solo el indice sin necesidad de escanear toda la tabla

CREATE INDEX idx_detalle_compra_covering
ON detalle_compra (id_compra, id_producto)
INCLUDE (cantidad, precio_unitario, descuento_aplicado);


VACUUM ANALYZE detalle_compra;
VACUUM ANALYZE compra;
VACUUM ANALYZE producto;


-- Analizar la segunda query seleccionada.
EXPLAIN ANALYZE
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


-- indice propuesto

-- la principal fuente de lentitud de la consulta es el WHERE de ahi que se busque
-- optimizarlo, el siguiente indice agilizara la busqeuda de las compras por la fecha
-- la compra y el cliente, lo cual le permitira acceder directamente a ellas sin recorrer la tabla
-- luego se comparara empiricamente con la salida sin optimizar

CREATE INDEX idx_compra_fecha_cliente ON compra (fecha_hora, id_cliente, id_compra);

VACUUM ANALYZE compra;
VACUUM ANALYZE detalle_compra;