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

CALL ventas_segmento('Consumer', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Corporate', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Home Office', NULL, NULL, NULL, NULL);