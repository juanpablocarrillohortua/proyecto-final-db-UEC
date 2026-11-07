-- ¿Cómo evolucionan las ganancias y pérdidas al agruparlas por distintos
-- intervalos temporales (mes, trimestre, anio)?
SELECT * FROM evolucion_periodo('anio');
SELECT * FROM evolucion_periodo('trimestre');
SELECT * FROM evolucion_periodo('mes');

-- ¿Cuáles son los productos más vendidos según la temporada?
SELECT * FROM v_productos_temporada;

-- ¿Qué tanto difiere el tiempo de entrega real del esperado?
SELECT * FROM v_entrega_por_bodega;
SELECT * FROM v_entrega_total;

-- ¿De qué ubicaciones proviene el mayor volumen de ventas (país, estado, ciudad,
-- código postal)?
SELECT * FROM ventas_por_ubicacion('pais');
SELECT * FROM ventas_por_ubicacion('estado');
SELECT * FROM ventas_por_ubicacion('ciudad');
SELECT * FROM ventas_por_ubicacion('codigo_postal');

-- ¿Cómo se distribuyen las ventas y la utilidad entre los distintos segmentos de clientes?
CALL ventas_segmento('Consumer', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Corporate', NULL, NULL, NULL, NULL);
CALL ventas_segmento('Home Office', NULL, NULL, NULL, NULL);

-- ¿Qué tan eficaces son los descuentos para impulsar las ventas y cómo
-- afectan la utilidad?
SELECT * FROM ventas_con_descuento;

-- ¿Qué categorías y subcategorías dan la mayor utilidad,
-- y cuáles generan pérdidas?
SELECT * FROM obtener_utilidad_por_categoria_o_subcategoria('categoria');
SELECT * FROM obtener_utilidad_por_categoria_o_subcategoria('categoria', TRUE);
SELECT * FROM obtener_utilidad_por_categoria_o_subcategoria('subcategoria');
SELECT * FROM obtener_utilidad_por_categoria_o_subcategoria('subcategoria', TRUE);

-- ¿Qué tipo de clientes concentran el mayor valor total de compras?
SELECT * FROM ventas_por_tipo_cliente;

-- ¿Cuál es el valor promedio de una compra y cuántas líneas de detalle
-- (entradas en la tabla detalle de compra) contiene en promedio?
SELECT * FROM compras_con_lineas;

-- ¿Existen regiones donde un alto volumen de ventas coincida con una utilidad
-- baja o negativa?
SELECT * FROM ventas_por_region_volumen;
