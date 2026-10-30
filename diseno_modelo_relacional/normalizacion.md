# Resumen de por qué se cumplen las formas normales

## Cumplimiento de 1FN
Note que se cumple ya que ninguna de las tablas tiene campos no atómicos, es decir, **no tiene columnas que contengan dos variables** o elementos como tuplas o listas; además, se establece un solo tipo de datos por columna.

## Cumplimiento de 2FN

Dado que ya se cumple la primera forma normal, la segunda se cumple ya que en las tablas con claves primarias compuestas (como `detalle_compra` o `inventario`) no hay una dependencia parcial de los atributos con la *primary key*. En detalle compra, la cantidad dentro de la compra tanto como el descuento dependen totalmente de qué producto se vende (id_producto) y en qué compra (id_compra). Y en inventario, de nuevo, la cantidad que hay del producto depende del producto y en qué bodega/sucursal está almacenado.

## Cumplimiento de 3FN

Note que la tercera forma normal se cumple ya que la segunda ya se cumple y, además, no hay atributos que dependan transitivamente de la clave primaria, es decir, no hay columnas que dependan de otras columnas no primarias.

## Cumplimiento parcial de BCNF

Se cumple, ya que en todas las tablas cada determinante es una clave candidata. En las tablas de clientes, `cedula` (en `cliente_nat`) y `nit` (en `cliente_corp`) determinan los demás atributos, pero esto no viola la BCNF: ambos son claves candidatas, aunque no se hayan elegido como clave primaria. Ademas se declaran con una restricción `UNIQUE` para garantizar esa unicidad en la base de datos.

# Tabla de claves primarias y foraneas

| Tabla           | Columna          | Tipo de clave | Referencia                       |
|-----------------|------------------|---------------|----------------------------------|
| PAIS            | id_pais          | PK            | —                                |
| ESTADO          | id_estado        | PK            | —                                |
| ESTADO          | id_pais          | FK            | PAIS(id_pais)                    |
| CIUDAD          | id_ciudad        | PK            | —                                |
| CIUDAD          | id_estado        | FK            | ESTADO(id_estado)                |
| CODIGO_POSTAL   | id_codigo        | PK            | —                                |
| CODIGO_POSTAL   | id_ciudad        | FK            | CIUDAD(id_ciudad)                |
| REGION          | id_region        | PK            | —                                |
| SEGMENTO        | id_segmento      | PK            | —                                |
| CLIENTE         | id_cliente       | PK            | —                                |
| CLIENTE         | id_codigo        | FK            | CODIGO_POSTAL(id_codigo)         |
| CLIENTE         | id_region        | FK            | REGION(id_region)                |
| CLIENTE         | id_segmento      | FK            | SEGMENTO(id_segmento)            |
| CLIENTE_NAT     | id_cliente       | PK / FK       | CLIENTE(id_cliente)              |
| CLIENTE_CORP    | id_cliente       | PK / FK       | CLIENTE(id_cliente)              |
| SUCURSAL        | id_sucursal      | PK            | —                                |
| COMPRA          | id_compra        | PK            | —                                |
| COMPRA          | id_cliente       | FK            | CLIENTE(id_cliente)              |
| COMPRA          | id_sucursal      | FK            | SUCURSAL(id_sucursal)            |
| ENVIO           | id_envio         | PK            | —                                |
| ENVIO           | id_compra        | FK            | COMPRA(id_compra)                |
| CATEGORIA       | id_categoria     | PK            | —                                |
| SUBCATEGORIA    | id_subcategoria  | PK            | —                                |
| SUBCATEGORIA    | id_categoria     | FK            | CATEGORIA(id_categoria)          |
| PRODUCTO        | id_producto      | PK            | —                                |
| PRODUCTO        | id_subcategoria  | FK            | SUBCATEGORIA(id_subcategoria)    |
| DETALLE_COMPRA  | id_compra        | PK / FK       | COMPRA(id_compra)                |
| DETALLE_COMPRA  | id_producto      | PK / FK       | PRODUCTO(id_producto)            |
| INVENTARIO      | id_producto      | PK / FK       | PRODUCTO(id_producto)            |
| INVENTARIO      | id_sucursal      | PK / FK       | SUCURSAL(id_sucursal)            |