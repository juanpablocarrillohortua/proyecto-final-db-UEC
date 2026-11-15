# Transaccion creada

Esta seccion desarrollo una transaccion que registra una compra, sus detalles y actualiza el inventario.

## Transaccion
```sql
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
```

Adicionalmente dentro de python se genero un script que facilita la llamada al procedimiento, este se llama con los siguientes comandos.

```shell
python optimizacion_transacciones\transacciones\llamar_transaccion.py
```

o si desea cambiar los parametros

```shell
python optimizacion_transacciones\transacciones\llamar_transaccion.py id_cliente id_sucursal carro tipo_compra

python optimizacion_transacciones\transacciones\llamar_transaccion.py 100 1 '{"10": [5.0, 1]}' ONLINE
```

---

## Cómo se evidencian las propiedades ACID.

En esta transaccion (implementada dentro de un procedimiento), las propiedades ACID se evidancian ya que si algun eslabon de la actualizacion falla (por ejemplo hay un stock negativo o ineficietne que hace que un check de las tablas salte) todos los cambios se revierten y no se ve ninguna modificacion en la base de datos, de esta manera presentando atomicidad y consistencia en los datos (pues garantiza nunca actualizar de manera incorrecta el stock o registrar compras sin actualizar el stock), adicionalmente estas propiedades tambien se evidencian en la insercion de detalles de la compra, lo cual garantiza que todos correspondan al mismo id y que asimismo todos se inserten de manera adecuada, la durabilidad se hace presente en el momento de confirmar la transaccion, pues los cambios que hechos sin fallos perdiran en la base de datos y el aislamiento garantiza que las transacciones concurrentes no interfieran entre sí mientras se ejecutan (como si ocurrieran de forma aislada), evitando que vean estados intermedios incompletos.

---

## Posible escenario de concurrencia y la anomalía que podría producirse.

Si no se tuviuese la transaccion podria darse el caso que 2 sesiones ejecuten una compra simultaneamente en productos con poco stock, de esta manera se registraria una compra de manera exitosa y con la actualizacion de stock adecuada, pero otra compra registraria la compra de un producto sin stock, lo cual generaria una inconsistencia, la transaccion resuelve esto poniendo en cola las actualizaciones, de tal manera que una trasaccion se ejecutara despues de la otra y utilizando la informacion que la anterior ya actualizo, evitando de esta manera la venta de productos sin stock.

---

## Nivel de aislamiento


Para esta implementación se utiliza el nivel de aislamiento `READ COMMITTED` (nivel por defecto en PostgreSQL), complementado con el modo de ejecución `AUTOCOMMIT` en el cliente de Python (SQLAlchemy).

- En Python (`AUTOCOMMIT`): Se configura en la conexión de Python para evitar que SQLAlchemy abra una transacción externa envolviendo la llamada del procedimiento, delegando así el control explícito del COMMIT y ROLLBACK al procedimiento almacenado en PostgreSQL.

- En PostgreSQL (`READ COMMITTED`): Es el nivel adecuado para este tipo de transaccion de alta frecuencia porque evita lecturas sucias y garantiza que, cuando una segunda transacción espera por el bloqueo de fila de un UPDATE, al reanudarse lea siempre el último valor confirmado (COMMIT) por la transacción anterior (como se vio en los talleres de clase). De este modo se mantiene la integridad del inventario.