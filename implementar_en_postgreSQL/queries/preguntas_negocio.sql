-- Venta y utilidad de cada línea de compra.

CREATE VIEW v_lineas_venta AS
SELECT
    d.id_compra,
    d.id_producto,
    d.cantidad,
    d.cantidad * d.precio_unitario * (1 - d.descuento_aplicado / 100) AS venta,
    d.cantidad * d.precio_unitario * (1 - d.descuento_aplicado / 100)
        - d.cantidad * p.precio_compra AS utilidad
FROM detalle_compra d
JOIN producto p ON p.id_producto = d.id_producto;

-- Venta de cada línea junto con la ubicación del cliente.

CREATE VIEW v_ventas_ubicacion AS
SELECT
    pa.nombre_pais AS pais,
    e.nombre_estado AS estado,
    ci.nombre_ciudad AS ciudad,
    cp.codigo AS codigo_postal,
    l.venta
FROM v_lineas_venta l
JOIN compra c ON c.id_compra = l.id_compra
JOIN cliente cl ON cl.id_cliente = c.id_cliente
JOIN codigo_postal cp ON cp.id_codigo = cl.id_codigo
JOIN ciudad ci ON ci.id_ciudad = cp.id_ciudad
JOIN estado_departamento e ON e.id_estado = ci.id_estado
JOIN pais pa ON pa.id_pais = e.id_pais;

-- Días esperados y días reales de cada envío entregado.

CREATE VIEW v_tiempos_entrega AS
SELECT
    c.id_sucursal,
    DATE(e.fecha_esperada) - DATE(c.fecha_hora) AS dias_esperados,
    DATE(e.fecha_entrega) - DATE(c.fecha_hora) AS dias_reales
FROM envio e
JOIN compra c ON c.id_compra = e.id_compra
WHERE e.fecha_entrega IS NOT NULL;

-- ¿Cómo evolucionan las ganancias y pérdidas al agruparlas por distintos
-- intervalos temporales (mes, trimestre, anio)?

-- Por AÑO

SELECT
    EXTRACT(YEAR FROM c.fecha_hora) AS anio,
    ROUND(SUM(CASE 
                WHEN l.utilidad > 0 THEN l.utilidad
                ELSE 0 END), 2) AS ganancias,
    ROUND(SUM(CASE 
                WHEN l.utilidad < 0 THEN l.utilidad 
                ELSE 0 END), 2) AS perdidas,
    ROUND(SUM(l.utilidad), 2) AS utilidad_neta
FROM v_lineas_venta l
JOIN compra c ON c.id_compra = l.id_compra
GROUP BY anio
HAVING SUM(l.venta) > 0
ORDER BY anio;

-- Por TRIMESTRE

SELECT
    EXTRACT(YEAR FROM c.fecha_hora) AS anio,
    EXTRACT(QUARTER FROM c.fecha_hora) AS trimestre,
    ROUND(SUM(CASE
                WHEN l.utilidad > 0 THEN l.utilidad 
                ELSE 0 END), 2) AS ganancias,
    ROUND(SUM(CASE
                WHEN l.utilidad < 0 THEN l.utilidad 
                ELSE 0 END), 2) AS perdidas,
    ROUND(SUM(l.utilidad), 2) AS utilidad_neta
FROM v_lineas_venta l
JOIN compra c ON c.id_compra = l.id_compra
GROUP BY anio, trimestre
HAVING SUM(l.venta) > 0
ORDER BY anio, trimestre;

-- Por MES

SELECT
    EXTRACT(YEAR FROM c.fecha_hora) AS anio,
    EXTRACT(MONTH FROM c.fecha_hora) AS mes,
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

-- ¿Cuáles son los productos más vendidos según la temporada?

WITH ventas_temporada AS (
    SELECT
        EXTRACT(QUARTER FROM c.fecha_hora) AS trimestre,
        p.nombre_prod AS producto,
        SUM(l.cantidad) AS unidades_vendidas
    FROM v_lineas_venta l
    JOIN compra c ON c.id_compra = l.id_compra
    JOIN producto p ON p.id_producto = l.id_producto
    GROUP BY trimestre, producto
    HAVING SUM(l.cantidad) >= 30
)
SELECT trimestre, producto, unidades_vendidas
FROM ventas_temporada
ORDER BY trimestre, unidades_vendidas DESC;

-- ¿Qué tanto difiere el tiempo de entrega real del esperado?

-- Por BODEGA

SELECT
    s.nombre AS bodega,
    COUNT(*) AS envios,
    ROUND(AVG(t.dias_esperados), 2) AS dias_esperados,
    ROUND(AVG(t.dias_reales), 2) AS dias_reales,
    ROUND(AVG(t.dias_reales - t.dias_esperados), 2) AS diferencia
FROM v_tiempos_entrega t
JOIN sucursal s ON s.id_sucursal = t.id_sucursal
GROUP BY s.nombre
HAVING COUNT(*) >= 30
ORDER BY diferencia DESC;

-- Total de todos los envios

SELECT
    COUNT(*) AS envios,
    ROUND(AVG(dias_esperados), 2) AS dias_esperados,
    ROUND(AVG(dias_reales), 2) AS dias_reales,
    ROUND(AVG(dias_reales - dias_esperados), 2) AS diferencia
FROM v_tiempos_entrega;

-- ¿De qué ubicaciones proviene el mayor volumen de ventas (país, estado, ciudad,
-- código postal)?

-- PAIS

SELECT pais, ROUND(SUM(venta), 2) AS ventas
FROM v_ventas_ubicacion
GROUP BY pais
HAVING SUM(venta) > 0
ORDER BY ventas DESC;

-- ESTADO

SELECT estado, ROUND(SUM(venta), 2) AS ventas
FROM v_ventas_ubicacion
GROUP BY estado
HAVING SUM(venta) >= 50000
ORDER BY ventas DESC;

-- CIUDAD

SELECT ciudad, estado, ROUND(SUM(venta), 2) AS ventas
FROM v_ventas_ubicacion
GROUP BY ciudad, estado
HAVING SUM(venta) >= 30000
ORDER BY ventas DESC;

-- CODIGO POSTAL

SELECT codigo_postal, ciudad, ROUND(SUM(venta), 2) AS ventas
FROM v_ventas_ubicacion
GROUP BY codigo_postal, ciudad
HAVING SUM(venta) >= 20000
ORDER BY ventas DESC;

-- ¿Cómo se distribuyen las ventas y la utilidad entre los distintos segmentos de clientes?

CREATE OR REPLACE PROCEDURE ventas_segmento(
    IN p_segmento VARCHAR,
    OUT ventas NUMERIC,
    OUT porcentaje_ventas NUMERIC,
    OUT utilidad_total NUMERIC,
    OUT porcentaje_utilidad NUMERIC
)
AS $$
BEGIN
    SELECT
        ROUND(SUM(l.venta), 2),
        ROUND(100 * SUM(l.venta) / (SELECT SUM(venta) FROM v_lineas_venta), 2),
        ROUND(SUM(l.utilidad), 2),
        ROUND(100 * SUM(l.utilidad) / (SELECT SUM(utilidad) FROM v_lineas_venta), 2)
    INTO ventas, porcentaje_ventas, utilidad_total, porcentaje_utilidad
    FROM v_lineas_venta l
    JOIN compra c ON c.id_compra = l.id_compra
    JOIN cliente cl ON cl.id_cliente = c.id_cliente
    JOIN segmento sg ON sg.id_segmento = cl.id_segmento
    WHERE sg.nombre_segmento = p_segmento
    GROUP BY sg.nombre_segmento
    HAVING SUM(l.venta) > 0;
END;
$$ LANGUAGE plpgsql;




-- ¿Qué tan eficaces son los descuentos para impulsar las ventas y cómo
-- afectan la utilidad?

DROP VIEW IF EXISTS ventas_con_descuento;
CREATE VIEW ventas_con_descuento AS
SELECT
    CASE
        WHEN dt.descuento_aplicado > 0 THEN 'Con Descuento'
        ELSE 'Sin Descuento'
    END AS descuento,
    ROUND(
        ((COUNT(*) * 1.0) / (SELECT COUNT(*) FROM detalle_compra) * 100), 2)
        AS porcentaje_lineas,
    SUM(dt.cantidad) AS unidades_vendidas,
    ROUND(SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100) * dt.cantidad), 2) AS total_ventas,
    ROUND(SUM((dt.precio_unitario * (1 - dt.descuento_aplicado / 100) - p.precio_compra) * dt.cantidad), 2)
        AS utilidad_total,
    ROUND(AVG((dt.precio_unitario * (1 - dt.descuento_aplicado / 100) - p.precio_compra) * dt.cantidad), 2)
        AS utilidad_promedio,
    ROUND(
            SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100)) - p.precio_compra) * dt.cantidad) * 100.0 /
            NULLIF(SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100) * dt.cantidad), 0),
        2) AS porcentaje_margen_utilidad
FROM detalle_compra AS dt
JOIN producto AS p ON dt.id_producto = p.id_producto
GROUP BY descuento;

-- ¿Qué categorías y subcategorías dan la mayor utilidad,
-- y cuáles generan pérdidas?

CREATE OR REPLACE VIEW utilidad_por_subcategoria AS
SELECT
    sc.nombre_subcategoria,
    SUM(dt.cantidad) AS unidades_vendidas,
    ROUND(SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0)) - p.precio_compra) * dt.cantidad), 2) AS utilidad_total,
    ROUND(
        SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100)) - p.precio_compra) * dt.cantidad) * 100.0 /
        NULLIF(SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100) * dt.cantidad), 0),
    2) AS porcentaje_margen_utilidad

FROM detalle_compra AS dt
JOIN producto AS p ON dt.id_producto = p.id_producto
JOIN subcategoria AS sc ON p.id_subcategoria = sc.id_subcategoria
GROUP BY sc.nombre_subcategoria
ORDER BY porcentaje_margen_utilidad DESC;


CREATE OR REPLACE VIEW utilidad_por_categoria AS

SELECT
    c.nombre_categoria,
    SUM(dt.cantidad) AS unidades_vendidas,
    ROUND(SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0)) - p.precio_compra) * dt.cantidad), 2) AS utilidad_total,
    ROUND(
        SUM(((dt.precio_unitario * (1 - dt.descuento_aplicado / 100)) - p.precio_compra) * dt.cantidad) * 100.0 /
        NULLIF(SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100) * dt.cantidad), 0),
    2) AS porcentaje_margen_utilidad

FROM detalle_compra AS dt
JOIN producto AS p ON dt.id_producto = p.id_producto
JOIN subcategoria AS sc ON p.id_subcategoria = sc.id_subcategoria
JOIN categoria AS c ON sc.id_categoria = c.id_categoria
GROUP BY c.nombre_categoria
ORDER BY porcentaje_margen_utilidad DESC;

CREATE OR REPLACE FUNCTION obtener_utilidad_por_categoria_o_subcategoria(tipo_agrupacion TEXT, lost_first BOOLEAN DEFAULT FALSE)
RETURNS TABLE (
    nombre VARCHAR(64),
    unidades_vendidas BIGINT,
    utilidad_total NUMERIC,
    porcentaje_margen_utilidad NUMERIC
) AS $$
BEGIN
    IF tipo_agrupacion = 'categoria' THEN
        RETURN QUERY
            SELECT * FROM utilidad_por_categoria AS v
            ORDER BY CASE WHEN lost_first THEN v.utilidad_total END ASC,
                     v.utilidad_total DESC;
    ELSIF tipo_agrupacion = 'subcategoria' THEN
        RETURN QUERY
            SELECT * FROM utilidad_por_subcategoria AS v
            ORDER BY CASE WHEN lost_first THEN v.utilidad_total END ASC,
                     v.utilidad_total DESC;
    ELSE
        RAISE EXCEPTION 'Tipo de agrupación inválido. Use "categoria" o "subcategoria".';
    END IF;
END;
$$ LANGUAGE plpgsql;


-- ¿Qué tipo de clientes concentran el mayor valor total de compras?

CREATE OR REPLACE VIEW ventas_por_tipo_cliente AS
WITH ventas_por_cliente AS (
    SELECT
        c.tipo_cliente,
        c.id_cliente,
        SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0) * dt.cantidad) AS gasto_cliente
    FROM cliente AS c
    JOIN compra AS co ON c.id_cliente = co.id_cliente
    JOIN detalle_compra AS dt ON co.id_compra = dt.id_compra
    GROUP BY c.tipo_cliente, c.id_cliente
)
SELECT
    tipo_cliente,
    COUNT(id_cliente) AS cantidad_clientes,
    ROUND(
        COUNT(id_cliente) * 1.0 / SUM(COUNT(id_cliente)) OVER (),
        4
    ) AS proporcion_clientes,
    ROUND(SUM(gasto_cliente), 2) AS valor_total_compras,
    -- Promedio del gasto total de cada cliente (no de cada compra).
    ROUND(AVG(gasto_cliente), 2) AS valor_promedio_por_cliente,
    ROUND(
        SUM(gasto_cliente) * 100.0 / SUM(SUM(gasto_cliente)) OVER (),
        2
    ) AS porcentaje_facturacion
FROM ventas_por_cliente
GROUP BY tipo_cliente
ORDER BY valor_total_compras DESC;


-- 9. ¿Cuál es el valor promedio de una compra y cuántas líneas de detalle
-- (entradas en la tabla detalle de compra) contiene en promedio?

CREATE OR REPLACE VIEW compras_con_lineas AS
WITH compras_con_lineas AS (
    SELECT
        co.id_compra,
        SUM(dt.precio_unitario * (1 - dt.descuento_aplicado / 100.0) * dt.cantidad) AS total_compra,
        COUNT(*) AS cantidad_lineas,
        SUM(dt.cantidad) AS total_productos
    FROM compra AS co
    JOIN detalle_compra AS dt ON co.id_compra = dt.id_compra
    GROUP BY co.id_compra
)
SELECT
    ROUND(AVG(total_compra), 2) AS valor_promedio_compra,
    ROUND(AVG(cantidad_lineas), 2) AS promedio_lineas_detalle,
    ROUND(AVG(total_productos), 2) AS promedio_productos_vendidos
FROM compras_con_lineas;

-- ¿Existen regiones donde un alto volumen de ventas coincida con una utilidad
--baja o negativa?

CREATE OR REPLACE VIEW ventas_por_region_volumen AS
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



CALL ventas_segmento('Consumer', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Corporate', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Home Office', NULL, NULL, NULL, NULL);
