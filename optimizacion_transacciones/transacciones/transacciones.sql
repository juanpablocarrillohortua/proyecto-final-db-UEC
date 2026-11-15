-- Un proceso clave que requiere transacciones atomicas es el registro de
-- Una compra, con sus detalles y actualizando el inventario.

-- La transaccion se va a definir dentro de un procedimiento almacenado
-- esto con el fin de reutilizarla


-- p_productos acepta JSON con la estructura {id_prod: [descuento, cantidad],
--                                                ...}
CREATE OR REPLACE PROCEDURE comprar(
    p_cliente_id BIGINT,
    p_sucursal_id BIGINT,
    p_productos JSONB,
    p_tipo_de_compra VARCHAR(64)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_compra_id BIGINT;
BEGIN
    -- Registrar la cabecera de la compra
    INSERT INTO compra (tipo_compra, id_cliente, id_sucursal)
    VALUES (p_tipo_de_compra, p_cliente_id, p_sucursal_id)
    RETURNING id_compra INTO v_compra_id;

    -- Insertar los detalles desarmando el objeto JSONB
    INSERT INTO detalle_compra (
        id_compra,
        id_producto,
        cantidad,
        precio_unitario,
        descuento_aplicado
    )
    SELECT
        v_compra_id,
        item.key::BIGINT,                       -- Convierte la llave ("10") a BIGINT
        (item.value->>1)::INT,                  -- Índice 1 de la tupla/lista: cantidad
        p.precio_venta,                        -- Precio vigente desde la tabla producto
        COALESCE((item.value->>0)::NUMERIC, 0)  -- Índice 0 de la tupla/lista: descuento
    FROM jsonb_each(p_productos) AS item(key, value)
    INNER JOIN producto p ON p.id_producto = item.key::BIGINT;

    -- Actualizar el inventario
    UPDATE inventario i
    SET cantidad = i.cantidad - (item.value->>1)::INT
    FROM jsonb_each(p_productos) AS item(key, value)
    WHERE i.id_producto = item.key::BIGINT
    AND i.id_sucursal = p_sucursal_id;

    -- Confirmar la transacción
    COMMIT;
END;
$$;

-- Ejemplo de llamada

-- CALL comprar(
--     100,                                        -- p_cliente_id
--     1,                                          -- p_sucursal_id
--     '{"10": [10.00, 2], "25": [0.00, 3]}'::jsonb, -- p_productos {id: [desc, cant]}
--     'TIENDA_FISICA'                             -- p_tipo_de_compra
-- );