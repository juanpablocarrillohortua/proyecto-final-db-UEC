<div style="width:100%; background-color:#00522c; border-bottom:3px solid #34a853; padding:20px 0; text-align:center;">
  <img src="https://pattern-lab-externado-prod.web.app/images/logo-uec.svg" alt="Banner del proyecto" width="40%">
</div>

# Relación de las preguntas y las consultas

En el archivo llamado `implementar_en_postgreSQL\queries\ejemplo_llamadas.sql` se implemento un ejemplo de como llamar cada vista, funcion y procedimiento, y a su vez se relaciono con que pregunta del negocio resuelve.


## Guía de preguntas y consultas

Los números de línea son una guía: pueden cambiar si se editan los archivos.

| # | Pregunta | Objetos | Consulta en `preguntas_negocio.sql` (primeras líneas) | Inicio en `ejemplo_llamadas.sql` |
|---|---|---|---|---|
| 1 | ¿Cómo evolucionan las ganancias y pérdidas por mes, trimestre y año? | `v_utilidad_anual`, `v_utilidad_trimestral`, `v_utilidad_mensual`, `evolucion_periodo()` | [L55](preguntas_negocio.sql#L55)<br>`CREATE VIEW v_utilidad_anual AS SELECT EXTRACT(YEAR FROM c.fecha_hora)::INT AS anio, …`<br>`CREATE VIEW v_utilidad_trimestral AS SELECT EXTRACT(YEAR FROM c.fecha_hora)::INT AS anio, EXTRACT(QUARTER FROM c.fecha_hora)::INT AS trimestre, …`<br>`CREATE VIEW v_utilidad_mensual AS SELECT EXTRACT(YEAR FROM c.fecha_hora)::INT AS anio, EXTRACT(MONTH FROM c.fecha_hora)::INT AS mes, …`<br>`CREATE OR REPLACE FUNCTION evolucion_periodo(tipo_agrupacion TEXT) …` | [1](ejemplo_llamadas.sql#L1) |
| 2 | ¿Cuáles son los productos más vendidos según la temporada? | `v_productos_temporada` | [L145](preguntas_negocio.sql#L145)<br>`CREATE VIEW v_productos_temporada AS WITH ventas_temporada AS ( SELECT EXTRACT(QUARTER FROM c.fecha_hora) AS trimestre, p.nombre_prod AS producto, …` | [7](ejemplo_llamadas.sql#L7) |
| 3 | ¿Qué tanto difiere el tiempo de entrega real del esperado? | `v_entrega_por_bodega`, `v_entrega_total` | [L163](preguntas_negocio.sql#L163)<br>`CREATE VIEW v_entrega_por_bodega AS SELECT s.nombre AS bodega, …`<br>`CREATE VIEW v_entrega_total AS SELECT COUNT(*) AS envios, …` | [10](ejemplo_llamadas.sql#L10) |
| 4 | ¿De qué ubicaciones proviene el mayor volumen de ventas? | `v_ventas_pais`, `v_ventas_estado`, `v_ventas_ciudad`, `v_ventas_codigo_postal`, `ventas_por_ubicacion()` | [L190](preguntas_negocio.sql#L190)<br>`CREATE VIEW v_ventas_pais AS SELECT pais, ROUND(SUM(venta), 2) AS ventas …`<br>`CREATE VIEW v_ventas_estado AS SELECT estado, ROUND(SUM(venta), 2) AS ventas …`<br>`CREATE VIEW v_ventas_ciudad AS SELECT ciudad, estado, ROUND(SUM(venta), 2) AS ventas …`<br>`CREATE VIEW v_ventas_codigo_postal AS SELECT codigo_postal, ciudad, ROUND(SUM(venta), 2) AS ventas …`<br>`CREATE OR REPLACE FUNCTION ventas_por_ubicacion(tipo_agrupacion TEXT) …` | [14](ejemplo_llamadas.sql#L14) |
| 5 | ¿Cómo se distribuyen las ventas y la utilidad entre los segmentos de clientes? | `v_ventas_segmento`, `ventas_segmento` (procedimiento) | [L262](preguntas_negocio.sql#L262)<br>`CREATE VIEW v_ventas_segmento AS SELECT sg.nombre_segmento AS segmento, …`<br>`CREATE OR REPLACE PROCEDURE ventas_segmento( …` | [21](ejemplo_llamadas.sql#L21) |
| 6 | ¿Qué tan eficaces son los descuentos y cómo afectan la utilidad? | `ventas_con_descuento` | [L297](preguntas_negocio.sql#L297)<br>`CREATE VIEW ventas_con_descuento AS SELECT CASE WHEN dt.descuento_aplicado > 0 THEN 'Con Descuento' ELSE 'Sin Descuento' END AS descuento, …` | [26](ejemplo_llamadas.sql#L26) |
| 7 | ¿Qué categorías y subcategorías dan la mayor utilidad y cuáles generan pérdidas? | `utilidad_por_subcategoria`, `utilidad_por_categoria`, `obtener_utilidad_por_categoria_o_subcategoria()` | [L323](preguntas_negocio.sql#L323)<br>`CREATE VIEW utilidad_por_subcategoria AS SELECT sc.nombre_subcategoria, …`<br>`CREATE VIEW utilidad_por_categoria AS SELECT c.nombre_categoria, …`<br>`CREATE OR REPLACE FUNCTION obtener_utilidad_por_categoria_o_subcategoria(tipo_agrupacion TEXT, lost_first BOOLEAN DEFAULT FALSE) …` | [30](ejemplo_llamadas.sql#L30) |
| 8 | ¿Qué tipo de clientes concentran el mayor valor total de compras? | `ventas_por_tipo_cliente` | [L386](preguntas_negocio.sql#L386)<br>`CREATE VIEW ventas_por_tipo_cliente AS WITH ventas_por_cliente AS ( SELECT c.tipo_cliente, c.id_cliente, …` | [37](ejemplo_llamadas.sql#L37) |
| 9 | ¿Cuál es el valor promedio de una compra y cuántas líneas de detalle contiene? | `compras_con_lineas` | [L418](preguntas_negocio.sql#L418)<br>`CREATE VIEW compras_con_lineas AS WITH compras_con_lineas AS ( SELECT co.id_compra, …` | [40](ejemplo_llamadas.sql#L40) |
| 10 | ¿Existen regiones con alto volumen de ventas y utilidad baja o negativa? | `ventas_por_region_volumen` | [L438](preguntas_negocio.sql#L438)<br>`CREATE VIEW ventas_por_region_volumen AS WITH ventas_por_region AS ( SELECT r.id_region, r.nombre_region, …` | [44](ejemplo_llamadas.sql#L44) |

Las vistas base `v_lineas_venta`, `v_ventas_ubicacion` y `v_tiempos_entrega` (líneas [16](preguntas_negocio.sql#L16)–[53](preguntas_negocio.sql#L53)) las usan varias preguntas.