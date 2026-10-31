CREATE TABLE region (
    id_region BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_region VARCHAR(64) NOT NULL UNIQUE
);

-- Se modela como tabla (y no como CHECK o ENUM) porque se prevé que los
-- segmentos de clientes cambien por razones legales o de negocio; así se
-- pueden agregar o modificar como datos, sin alterar el esquema.
CREATE TABLE segmento (
    id_segmento BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_segmento VARCHAR(128) NOT NULL UNIQUE
);

CREATE TABLE pais (
    id_pais BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_pais VARCHAR(64) NOT NULL UNIQUE
);

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_categoria VARCHAR(64) NOT NULL UNIQUE
);

CREATE TABLE sucursal (
    id_sucursal BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(128) NOT NULL,
    latitud NUMERIC(10, 8) NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud NUMERIC(11, 8) NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    direccion VARCHAR(64) NOT NULL,
    tipo VARCHAR(32) NOT NULL,

    CONSTRAINT chk_tipo_sucursal CHECK (tipo IN ('TIENDA', 'BODEGA'))
);

CREATE TABLE estado_departamento(
    id_estado BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_estado VARCHAR(64) NOT NULL,
    id_pais BIGINT NOT NULL,

    UNIQUE (nombre_estado, id_pais),
    FOREIGN KEY (id_pais) REFERENCES pais(id_pais) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE ciudad (
    id_ciudad BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_ciudad VARCHAR(64) NOT NULL,
    id_estado BIGINT NOT NULL,

    UNIQUE (nombre_ciudad, id_estado),
    FOREIGN KEY (id_estado) REFERENCES estado_departamento(id_estado) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE codigo_postal (
    id_codigo BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_barrio VARCHAR(64) NOT NULL,
    codigo VARCHAR(6) NOT NULL CHECK (codigo ~ '^[0-9]{6}$'),
    id_ciudad BIGINT NOT NULL,

    FOREIGN KEY (id_ciudad) REFERENCES ciudad(id_ciudad) ON UPDATE CASCADE ON DELETE RESTRICT
);


CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_cliente VARCHAR(32) NOT NULL DEFAULT 'NATURAL' CHECK (tipo_cliente IN ('NATURAL', 'CORPORATIVO')),
    id_codigo BIGINT NOT NULL,
    id_region BIGINT NOT NULL,
    id_segmento BIGINT NOT NULL,

    FOREIGN KEY (id_codigo) REFERENCES codigo_postal(id_codigo) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (id_region) REFERENCES region(id_region) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (id_segmento) REFERENCES segmento(id_segmento) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE cliente_nat (
    id_cliente BIGINT PRIMARY KEY,
    cedula VARCHAR(32) NOT NULL UNIQUE,
    nombre VARCHAR(128) NOT NULL,
    apellido VARCHAR(128) NOT NULL,
    email VARCHAR(255),
    telefono VARCHAR(15) NOT NULL,

    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_cedula CHECK (cedula ~ '^[0-9]{5,15}$'),
    CONSTRAINT chk_email CHECK (
        email IS NULL OR (
            btrim(email) <> ''
            AND btrim(email) ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        )
    )
);

CREATE TABLE cliente_corp (
    id_cliente BIGINT PRIMARY KEY,
    nit VARCHAR(32) NOT NULL UNIQUE,
    razon_social VARCHAR(128) NOT NULL,
    email VARCHAR(255),
    telefono VARCHAR(15) NOT NULL,

    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_nit CHECK (nit ~ '^[0-9]{5,11}-[0-9]$'),
    CONSTRAINT chk_email CHECK (
        email IS NULL OR (
            btrim(email) <> ''
            AND btrim(email) ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        )
    )
);

-- Insersion simple de clientes nuevos implementado con un trigger que intercepta
-- una insersion a una vista, usa el INSTEAD OF que se explico en las presentaciones
CREATE VIEW v_clientes AS
SELECT
    c.id_cliente,
    c.tipo_cliente,
    c.id_codigo,
    c.id_region,
    c.id_segmento,
    cn.cedula,
    cn.nombre,
    cn.apellido,
    cc.nit,
    cc.razon_social,
    COALESCE(cn.email, cc.email) AS email,
    COALESCE(cn.telefono, cc.telefono) AS telefono
FROM cliente c
LEFT JOIN cliente_nat cn ON c.id_cliente = cn.id_cliente
LEFT JOIN cliente_corp cc ON c.id_cliente = cc.id_cliente;



CREATE OR REPLACE FUNCTION process_insert_cliente()
RETURNS TRIGGER AS $$
DECLARE
    v_id_cliente BIGINT;
    v_tipo VARCHAR(32);
BEGIN

    IF NEW.cedula IS NOT NULL AND NEW.nit IS NOT NULL THEN
        RAISE EXCEPTION 'No se pueden proporcionar Cédula y NIT simultáneamente. Debe ingresar uno u otro.';
    END IF;

    IF NEW.tipo_cliente IS NOT NULL THEN
        v_tipo := UPPER(NEW.tipo_cliente);
    ELSIF NEW.cedula IS NOT NULL THEN
        v_tipo := 'NATURAL';
    ELSIF NEW.nit IS NOT NULL THEN
        v_tipo := 'CORPORATIVO';
    ELSE
        RAISE EXCEPTION 'Debe proporcionar una cédula (Natural) o un NIT (Corporativo).';
    END IF;

    IF v_tipo = 'NATURAL' AND NEW.cedula IS NULL THEN
        RAISE EXCEPTION 'Para un cliente NATURAL debe proporcionar la cédula.';
    ELSIF v_tipo = 'CORPORATIVO' AND NEW.nit IS NULL THEN
        RAISE EXCEPTION 'Para un cliente CORPORATIVO debe proporcionar el NIT.';
    END IF;

    INSERT INTO cliente (tipo_cliente, id_codigo, id_region, id_segmento)
    VALUES (v_tipo, NEW.id_codigo, NEW.id_region, NEW.id_segmento)
    RETURNING id_cliente INTO v_id_cliente;

    IF v_tipo = 'NATURAL' THEN
        INSERT INTO cliente_nat (id_cliente, cedula, nombre, apellido, email, telefono)
        VALUES (v_id_cliente, NEW.cedula, NEW.nombre, NEW.apellido, NEW.email, NEW.telefono);

    ELSIF v_tipo = 'CORPORATIVO' THEN
        INSERT INTO cliente_corp (id_cliente, nit, razon_social, email, telefono)
        VALUES (v_id_cliente, NEW.nit, NEW.razon_social, NEW.email, NEW.telefono);

    ELSE
        RAISE EXCEPTION 'Tipo de cliente no válido: %', v_tipo;
    END IF;

    NEW.id_cliente := v_id_cliente;
    NEW.tipo_cliente := v_tipo;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_insert_v_clientes
INSTEAD OF INSERT ON v_clientes
FOR EACH ROW
EXECUTE FUNCTION process_insert_cliente();

-- Ejemplos de insersion

-- para persona natural:
-- INSERT INTO v_clientes (id_codigo, id_region, id_segmento, cedula, nombre, apellido, email, telefono)
-- VALUES (1, 1, 1, '1018234567', 'Juan', 'Pérez', 'juan@gmail.com', '3001234567')
-- RETURNING id_cliente;

-- para empresa
-- INSERT INTO v_clientes (id_codigo, id_region, id_segmento, nit, razon_social, email, telefono)
-- VALUES (1, 1, 1, '900123456-1', 'Supermercado Central S.A.S.', 'contacto@supercentral.com', '6015551234')
-- RETURNING id_cliente;


CREATE TABLE compra (
    id_compra BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_compra VARCHAR(64) NOT NULL CHECK (tipo_compra IN ('PRESENCIAL', 'ONLINE')),
    id_cliente BIGINT NOT NULL,
    id_sucursal BIGINT NOT NULL,

    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Se verifica que sea el tipo correcto con un trigger
    FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE envio (
    id_envio BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_esperada TIMESTAMPTZ NOT NULL,
    fecha_entrega TIMESTAMPTZ,
    id_compra BIGINT NOT NULL UNIQUE,

    FOREIGN KEY (id_compra) REFERENCES compra(id_compra) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE subcategoria (
    id_subcategoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_subcategoria VARCHAR(64) NOT NULL,
    id_categoria BIGINT NOT NULL,

    FOREIGN KEY (id_categoria) REFERENCES categoria(id_categoria) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_prod VARCHAR(128) NOT NULL,
    precio_venta NUMERIC(12, 2) NOT NULL CHECK (precio_venta > 0),
    precio_compra NUMERIC(12, 2) NOT NULL CHECK (precio_compra > 0),
    id_subcategoria BIGINT NOT NULL,

    FOREIGN KEY (id_subcategoria) REFERENCES subcategoria(id_subcategoria) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE inventario (
    id_producto BIGINT NOT NULL,
    id_sucursal BIGINT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad >= 0),

    PRIMARY KEY (id_producto, id_sucursal),
    FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON UPDATE CASCADE ON DELETE RESTRICT
);


CREATE TABLE detalle_compra (
    id_compra BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario > 0),
    descuento_aplicado NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK (descuento_aplicado BETWEEN 0 AND 100),

    PRIMARY KEY (id_compra, id_producto),
    FOREIGN KEY (id_compra) REFERENCES compra(id_compra) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Regla 12: compra ONLINE -> se despacha desde una BODEGA;
--           compra PRESENCIAL -> se realiza en una TIENDA.
-- Verifica que la insersion tenga sentido de negocio.
CREATE OR REPLACE FUNCTION validar_sucursal_compra()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_sucursal VARCHAR(32);
BEGIN
    SELECT tipo INTO v_tipo_sucursal
    FROM sucursal
    WHERE id_sucursal = NEW.id_sucursal;

    IF NEW.tipo_compra = 'ONLINE' AND v_tipo_sucursal <> 'BODEGA' THEN
        RAISE EXCEPTION 'Una compra ONLINE debe registrarse en una BODEGA (la sucursal % es %).',
            NEW.id_sucursal, v_tipo_sucursal;
    ELSIF NEW.tipo_compra = 'PRESENCIAL' AND v_tipo_sucursal <> 'TIENDA' THEN
        RAISE EXCEPTION 'Una compra PRESENCIAL debe registrarse en una TIENDA (la sucursal % es %).',
            NEW.id_sucursal, v_tipo_sucursal;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_sucursal_compra
BEFORE INSERT ON compra
FOR EACH ROW
EXECUTE FUNCTION validar_sucursal_compra();

-- Regla 1: solo las compras ONLINE pueden tener envío.
CREATE OR REPLACE FUNCTION validar_envio_compra()
RETURNS TRIGGER AS $$
DECLARE
    v_tipo_compra VARCHAR(64);
BEGIN
    SELECT tipo_compra INTO v_tipo_compra
    FROM compra
    WHERE id_compra = NEW.id_compra;

    IF v_tipo_compra <> 'ONLINE' THEN
        RAISE EXCEPTION 'La compra % es %; solo las compras ONLINE pueden tener envío.',
            NEW.id_compra, v_tipo_compra;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_validar_envio_compra
BEFORE INSERT OR UPDATE OF id_compra ON envio
FOR EACH ROW
EXECUTE FUNCTION validar_envio_compra();
