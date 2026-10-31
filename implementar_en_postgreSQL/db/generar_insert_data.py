"""Genera insert_data.sql a partir del dataset Superstore.

Uso:
    python generar_insert_data.py
    psql -U postgres -h localhost -d supermercado -v ON_ERROR_STOP=1 -f insert_data.sql

Decisiones generales:
- Ninguna tabla recibe un id explícito: todas las PK las genera la base de datos
  (GENERATED ALWAYS AS IDENTITY). Las FK se resuelven con subconsultas por clave
  natural o con currval() justo después de insertar la compra.
- Los ids del CSV (Row ID, Order ID, Customer ID, Product ID) no se guardan; solo
  se usan aquí para agrupar filas.
- Todo lo simulado usa una semilla fija, así el archivo generado siempre es igual.
"""

import random
import re
import unicodedata
from datetime import timedelta
from pathlib import Path

import pandas as pd

RAIZ = Path(__file__).resolve().parents[2]
RUTA_CSV = RAIZ / "data" / "Sample - Superstore.csv"
RUTA_SQL = Path(__file__).resolve().parent / "insert_data.sql"

random.seed(42)

# ---------------------------------------------------------------------------
# Datos de referencia simulados
# ---------------------------------------------------------------------------

CORREOS = ['gmail', 'hotmail', 'icloud', 'outlook', 'yahoo']

# La geografía del CSV es de EE. UU.; se reemplaza por la de Colombia.
# Cada región de EE. UU. se asigna a una región colombiana.
REGIONES = {
    "Central": "Andina",
    "East": "Caribe",
    "West": "Pacífica",
    "South": "Orinoquía",
}

# Región -> {departamento: (código DANE, municipios)}.
# El código DANE es el prefijo de los códigos postales del departamento.
DEPARTAMENTOS = {
    "Andina": {
        "Bogotá D.C.": ("11", ["Bogotá"]),
        "Antioquia": ("05", ["Medellín", "Envigado", "Bello", "Itagüí", "Rionegro"]),
        "Cundinamarca": ("25", ["Soacha", "Zipaquirá", "Chía", "Facatativá", "Girardot"]),
        "Santander": ("68", ["Bucaramanga", "Floridablanca", "Girón", "Barrancabermeja"]),
        "Boyacá": ("15", ["Tunja", "Duitama", "Sogamoso"]),
        "Caldas": ("17", ["Manizales", "Villamaría"]),
        "Risaralda": ("66", ["Pereira", "Dosquebradas"]),
        "Quindío": ("63", ["Armenia", "Calarcá"]),
        "Tolima": ("73", ["Ibagué", "Espinal"]),
        "Huila": ("41", ["Neiva", "Pitalito"]),
        "Norte de Santander": ("54", ["Cúcuta", "Ocaña"]),
    },
    "Caribe": {
        "Atlántico": ("08", ["Barranquilla", "Soledad", "Malambo", "Puerto Colombia"]),
        "Bolívar": ("13", ["Cartagena", "Magangué", "Turbaco"]),
        "Magdalena": ("47", ["Santa Marta", "Ciénaga"]),
        "Córdoba": ("23", ["Montería", "Lorica", "Sahagún"]),
        "Cesar": ("20", ["Valledupar", "Aguachica"]),
        "Sucre": ("70", ["Sincelejo", "Corozal"]),
        "La Guajira": ("44", ["Riohacha", "Maicao"]),
    },
    "Pacífica": {
        "Valle del Cauca": ("76", ["Cali", "Palmira", "Buenaventura", "Tuluá", "Jamundí"]),
        "Cauca": ("19", ["Popayán", "Santander de Quilichao"]),
        "Nariño": ("52", ["Pasto", "Ipiales", "Tumaco"]),
        "Chocó": ("27", ["Quibdó", "Istmina"]),
    },
    "Orinoquía": {
        "Meta": ("50", ["Villavicencio", "Acacías", "Granada"]),
        "Casanare": ("85", ["Yopal", "Aguazul"]),
        "Arauca": ("81", ["Arauca", "Saravena"]),
        "Vichada": ("99", ["Puerto Carreño"]),
    },
}

BARRIOS = [
    "Centro", "La Esperanza", "San José", "El Prado", "Los Alpes", "Villa del Río",
    "La Floresta", "El Recreo", "Santa Mónica", "Las Américas", "El Bosque",
    "San Fernando", "La Castellana", "Villa Nueva", "El Jardín", "Los Pinos",
]

SECTORES = ["Distribuciones", "Comercializadora", "Inversiones", "Suministros", "Servicios"]

# 3 tiendas + 1 bodega por región (regla 12: las compras ONLINE salen de una bodega).
# (nombre, región, tipo, latitud, longitud, dirección)
SUCURSALES = [
    ("Tienda Bogotá Chapinero", "Andina", "TIENDA", 4.6486, -74.0628, "Carrera 13 # 63-41"),
    ("Tienda Medellín El Poblado", "Andina", "TIENDA", 6.2088, -75.5676, "Carrera 43A # 7-50"),
    ("Tienda Bucaramanga Cabecera", "Andina", "TIENDA", 7.1186, -73.1105, "Calle 52 # 35-12"),
    ("Bodega Bogotá Fontibón", "Andina", "BODEGA", 4.6782, -74.1469, "Calle 17 # 116-30"),
    ("Tienda Barranquilla Norte", "Caribe", "TIENDA", 11.0041, -74.8070, "Carrera 53 # 80-15"),
    ("Tienda Cartagena Bocagrande", "Caribe", "TIENDA", 10.3997, -75.5514, "Avenida San Martín # 8-40"),
    ("Tienda Santa Marta Centro", "Caribe", "TIENDA", 11.2421, -74.2110, "Calle 15 # 4-20"),
    ("Bodega Barranquilla Zona Franca", "Caribe", "BODEGA", 10.9590, -74.7630, "Vía 40 # 85-100"),
    ("Tienda Cali Granada", "Pacífica", "TIENDA", 3.4600, -76.5320, "Avenida 9N # 15-30"),
    ("Tienda Popayán Centro", "Pacífica", "TIENDA", 2.4419, -76.6063, "Calle 5 # 6-25"),
    ("Tienda Pasto Centro", "Pacífica", "TIENDA", 1.2136, -77.2811, "Carrera 25 # 17-60"),
    ("Bodega Cali Acopi", "Pacífica", "BODEGA", 3.5120, -76.5020, "Calle 15 # 32-200"),
    ("Tienda Villavicencio Centro", "Orinoquía", "TIENDA", 4.1420, -73.6266, "Calle 38 # 30-15"),
    ("Tienda Yopal Centro", "Orinoquía", "TIENDA", 5.3378, -72.3959, "Carrera 20 # 9-40"),
    ("Tienda Arauca Centro", "Orinoquía", "TIENDA", 7.0847, -70.7591, "Calle 20 # 21-35"),
    ("Bodega Villavicencio Anillo Vial", "Orinoquía", "BODEGA", 4.1300, -73.6000, "Kilómetro 3 Vía Puerto López"),
]

# Días esperados de entrega según Ship Mode (promedios observados en el CSV).
DIAS_ESPERADOS = {"Same Day": 0, "First Class": 2, "Second Class": 3, "Standard Class": 5}

# El CSV no indica el canal; se asume que el 40 % de las compras son en línea.
PORCENTAJE_ONLINE = 0.4

# ---------------------------------------------------------------------------
# Funciones auxiliares
# ---------------------------------------------------------------------------


def texto(valor):
    """Literal SQL de texto; duplica las comillas simples (hay nombres como O'Donnell)."""
    return "'" + str(valor).replace("'", "''") + "'"


def buscar_id(tabla, columna_id, **filtros):
    """Subconsulta que obtiene el id autogenerado de una fila por su clave natural."""
    condiciones = " AND ".join(f"{columna} = {valor}" for columna, valor in filtros.items())
    return f"(SELECT {columna_id} FROM {tabla} WHERE {condiciones})"


def insert(tabla, columnas, filas):
    """INSERT con varias filas; cada fila es una lista de valores ya escritos en SQL."""
    valores = ",\n".join("    (" + ", ".join(fila) + ")" for fila in filas)
    return f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES\n{valores};\n"


def solo_letras(valor):
    """Quita tildes y todo lo que no sea letra, para armar correos válidos."""
    sin_tildes = unicodedata.normalize("NFKD", valor).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z]", "", sin_tildes.lower())


def fecha(valor):
    return texto(valor.strftime("%Y-%m-%d %H:%M:%S"))


# ---------------------------------------------------------------------------
# Preparación de los datos
# ---------------------------------------------------------------------------

df = pd.read_csv(RUTA_CSV, encoding="latin-1")
df["Order Date"] = pd.to_datetime(df["Order Date"], format="%m/%d/%Y")
df["Ship Date"] = pd.to_datetime(df["Ship Date"], format="%m/%d/%Y")

# Precio de lista unitario (antes del descuento) y costo unitario de cada línea.
df["precio_lista"] = (df["Sales"] / df["Quantity"] / (1 - df["Discount"])).round(2)
df["costo"] = (df["Sales"] - df["Profit"]) / df["Quantity"]

# Producto: una fila por nombre. Hay Product ID reutilizados para nombres distintos,
# así que el ID del CSV se ignora y la base de datos asigna id_producto.
# Si un nombre aparece con varios precios, se guarda el más frecuente y el costo promedio.
productos = df.groupby("Product Name").agg(
    subcategoria=("Sub-Category", "first"),
    precio_venta=("precio_lista", lambda s: s.mode().iloc[0]),
    precio_compra=("costo", "mean"),
)
productos["precio_compra"] = productos["precio_compra"].round(2)

# Cada estado de EE. UU. se asigna, en orden alfabético y de forma rotativa,
# a un departamento de la región colombiana equivalente.
departamento_de_estado = {}
for region_us, estados in df.groupby("Region")["State"].unique().items():
    departamentos = list(DEPARTAMENTOS[REGIONES[region_us]])
    for i, estado in enumerate(sorted(estados)):
        departamento_de_estado[estado] = departamentos[i % len(departamentos)]

codigo_dane = {
    departamento: dane
    for departamentos in DEPARTAMENTOS.values()
    for departamento, (dane, _) in departamentos.items()
}
municipios = {
    departamento: lista
    for departamentos in DEPARTAMENTOS.values()
    for departamento, (_, lista) in departamentos.items()
}

# Cada ciudad de EE. UU. (identificada por ciudad + estado, porque hay nombres repetidos)
# se asigna de forma rotativa a un municipio de su departamento.
ciudad_de = {}
for estado, ciudades in df.groupby("State")["City"].unique().items():
    departamento = departamento_de_estado[estado]
    for i, ciudad in enumerate(sorted(ciudades)):
        ciudad_de[(ciudad, estado)] = (municipios[departamento][i % len(municipios[departamento])], departamento)

# Cada código postal de EE. UU. recibe un código colombiano único de 6 dígitos:
# prefijo DANE del departamento + consecutivo, y un barrio al azar.
codigo_postal_de = {}
consecutivo = {}
direcciones = df[["Postal Code", "City", "State"]].drop_duplicates().sort_values(["State", "City", "Postal Code"])
for postal, ciudad, estado in direcciones.itertuples(index=False):
    municipio, departamento = ciudad_de[(ciudad, estado)]
    consecutivo[departamento] = consecutivo.get(departamento, 0) + 1
    codigo = codigo_dane[departamento] + f"{consecutivo[departamento]:04d}"
    codigo_postal_de[(postal, ciudad, estado)] = (codigo, random.choice(BARRIOS), municipio, departamento)

# En el CSV la dirección es de la orden, pero la regla 7 exige un único código postal
# por cliente: se toma la dirección más frecuente (en empate, la primera en orden).
frecuencia = (
    df.groupby(["Customer ID", "Postal Code", "City", "State", "Region"]).size().rename("n").reset_index()
    .sort_values(["Customer ID", "n", "Postal Code", "City"], ascending=[True, False, True, True])
    .drop_duplicates("Customer ID")
)
clientes = (
    df[["Customer ID", "Customer Name", "Segment"]].drop_duplicates()
    .merge(frecuencia, on="Customer ID")
    .sort_values("Customer ID")
    .rename(columns={
        "Customer ID": "id_csv", "Customer Name": "nombre", "Segment": "segmento",
        "Postal Code": "postal", "City": "ciudad", "State": "estado", "Region": "region",
    })
)

# Documentos y contactos simulados, únicos y válidos para los CHECK del esquema.
cedulas = random.sample(range(10**9, 10**10), len(clientes))
nits = random.sample(range(800_000_000, 1_000_000_000), len(clientes))

# ---------------------------------------------------------------------------
# Escritura del SQL
# ---------------------------------------------------------------------------

sql = []
sql.append("-- Archivo generado por generar_insert_data.py; no editar a mano.\n")
sql.append("-- Todas las PK las genera la base de datos; las FK se buscan por clave natural.\n")
sql.append("SET client_encoding = 'UTF8';\n")
sql.append("BEGIN;\n")
sql.append("-- Se vacían las tablas y se reinician los ids para poder ejecutar el script varias veces.\n")
sql.append(
    "TRUNCATE detalle_compra, envio, compra, inventario, cliente_nat, cliente_corp, cliente, "
    "producto, subcategoria, categoria, sucursal, codigo_postal, ciudad, estado_departamento, "
    "pais, segmento, region RESTART IDENTITY CASCADE;\n"
)

sql.append("\n-- País: toda la geografía se simula en Colombia.\n")
sql.append(insert("pais", ["nombre_pais"], [[texto("Colombia")]]))

sql.append("\n-- Regiones: las 4 regiones de EE. UU. renombradas como regiones de Colombia.\n")
sql.append(insert("region", ["nombre_region"], [[texto(r)] for r in REGIONES.values()]))

sql.append("\n-- Segmentos: tomados directamente del CSV.\n")
sql.append(insert("segmento", ["nombre_segmento"], [[texto(s)] for s in sorted(df["Segment"].unique())]))

sql.append("\n-- Departamentos: solo los que quedaron asignados a algún estado de EE. UU.\n")
id_colombia = buscar_id("pais", "id_pais", nombre_pais=texto("Colombia"))
sql.append(insert(
    "estado_departamento", ["nombre_estado", "id_pais"],
    [[texto(d), id_colombia] for d in sorted(set(departamento_de_estado.values()))],
))

sql.append("\n-- Ciudades: municipios a los que se asignó al menos una ciudad de EE. UU.\n")
sql.append(insert(
    "ciudad", ["nombre_ciudad", "id_estado"],
    [
        [texto(municipio), buscar_id("estado_departamento", "id_estado", nombre_estado=texto(departamento))]
        for municipio, departamento in sorted(set(ciudad_de.values()))
    ],
))


def id_ciudad(municipio, departamento):
    # Una ciudad se identifica por su nombre y su departamento (UNIQUE en el esquema).
    id_estado = buscar_id("estado_departamento", "id_estado", nombre_estado=texto(departamento))
    return buscar_id("ciudad", "id_ciudad", nombre_ciudad=texto(municipio), id_estado=id_estado)


sql.append("\n-- Códigos postales: uno por código postal de EE. UU.; los códigos son únicos.\n")
sql.append(insert(
    "codigo_postal", ["nombre_barrio", "codigo", "id_ciudad"],
    [
        [texto(barrio), texto(codigo), id_ciudad(municipio, departamento)]
        for codigo, barrio, municipio, departamento in codigo_postal_de.values()
    ],
))

sql.append("\n-- Categorías y subcategorías: tomadas directamente del CSV.\n")
sql.append(insert("categoria", ["nombre_categoria"], [[texto(c)] for c in sorted(df["Category"].unique())]))
subcategorias = df[["Sub-Category", "Category"]].drop_duplicates().sort_values("Sub-Category")
sql.append(insert(
    "subcategoria", ["nombre_subcategoria", "id_categoria"],
    [
        [texto(sub), buscar_id("categoria", "id_categoria", nombre_categoria=texto(cat))]
        for sub, cat in subcategorias.itertuples(index=False)
    ],
))

sql.append("\n-- Productos: uno por nombre. precio_venta = precio de lista más frecuente;\n")
sql.append("-- precio_compra = costo unitario promedio ((Sales - Profit) / Quantity).\n")
sql.append(insert(
    "producto", ["nombre_prod", "precio_venta", "precio_compra", "id_subcategoria"],
    [
        [
            texto(nombre), f"{p.precio_venta:.2f}", f"{p.precio_compra:.2f}",
            # El nombre de subcategoría es único en los datos, así que sirve como clave.
            buscar_id("subcategoria", "id_subcategoria", nombre_subcategoria=texto(p.subcategoria)),
        ]
        for nombre, p in productos.iterrows()
    ],
))

sql.append("\n-- Sucursales: simuladas, 3 tiendas y 1 bodega por región.\n")
sql.append(insert(
    "sucursal", ["nombre", "latitud", "longitud", "direccion", "tipo"],
    [[texto(n), str(lat), str(lon), texto(d), texto(t)] for n, _, t, lat, lon, d in SUCURSALES],
))

sql.append("\n-- Clientes: se insertan en la vista v_clientes; su trigger crea la fila en cliente\n")
sql.append("-- y en cliente_nat (si trae cédula) o cliente_corp (si trae NIT).\n")
sql.append("-- Corporate -> CORPORATIVO con NIT y razón social simulados; Consumer y Home Office -> NATURAL.\n")
filas_nat, filas_corp = [], []
id_cliente_sql = {}  # Customer ID -> subconsulta del id_cliente generado
for i, c in enumerate(clientes.itertuples(index=False)):
    # Nombre y apellido: se separa en el primer espacio; si no hay espacio, se repite.
    nombre, _, apellido = c.nombre.partition(" ")
    apellido = apellido or nombre
    codigo = codigo_postal_de[(c.postal, c.ciudad, c.estado)][0]
    comunes = [
        buscar_id("codigo_postal", "id_codigo", codigo=texto(codigo)),
        buscar_id("region", "id_region", nombre_region=texto(REGIONES[c.region])),
        buscar_id("segmento", "id_segmento", nombre_segmento=texto(c.segmento)),
    ]
    correo = f"{solo_letras(nombre)}.{solo_letras(apellido)}{i + 1}@{random.choice(CORREOS)}.com"
    if c.segmento == "Corporate":
        nit = f"{nits[i]}-{nits[i] % 10}"
        razon_social = f"{apellido} {random.choice(SECTORES)} S.A.S."
        telefono = f"601{random.randint(1_000_000, 9_999_999)}"  # fijo de Bogotá
        filas_corp.append(comunes + [texto(nit), texto(razon_social), texto(correo), texto(telefono)])
        id_cliente_sql[c.id_csv] = buscar_id("cliente_corp", "id_cliente", nit=texto(nit))
    else:
        telefono = f"3{random.randint(100_000_000, 999_999_999)}"  # celular
        filas_nat.append(comunes + [texto(cedulas[i]), texto(nombre), texto(apellido), texto(correo), texto(telefono)])
        id_cliente_sql[c.id_csv] = buscar_id("cliente_nat", "id_cliente", cedula=texto(cedulas[i]))

sql.append(insert(
    "v_clientes", ["id_codigo", "id_region", "id_segmento", "cedula", "nombre", "apellido", "email", "telefono"],
    filas_nat,
))
sql.append(insert(
    "v_clientes", ["id_codigo", "id_region", "id_segmento", "nit", "razon_social", "email", "telefono"],
    filas_corp,
))

sql.append("\n-- Compras: una por Order ID, en orden cronológico. Como compra no tiene clave natural,\n")
sql.append("-- su detalle y su envío usan currval(), el id que la base de datos acaba de generar.\n")
sql.append("-- La hora (08:00-20:59) y el canal (40 % ONLINE) son simulados. PRESENCIAL -> tienda de la\n")
sql.append("-- región del cliente; ONLINE -> bodega de esa región, con envío (reglas 1 y 12).\n")
sql.append("-- fecha_esperada = fecha + días típicos del Ship Mode; fecha_entrega = fecha + días reales del CSV.\n")
region_de_cliente = dict(zip(clientes["id_csv"], clientes["region"].map(REGIONES)))
id_compra = "currval('compra_id_compra_seq')"

# Las líneas repetidas de un mismo producto en una orden (mismo precio y descuento)
# se fusionan sumando la cantidad, porque la PK de detalle_compra es (compra, producto).
# precio_unitario es el precio de lista de esa línea: el precio al momento de la venta.
lineas = (
    df.groupby(["Order ID", "Product Name"])
    .agg(cantidad=("Quantity", "sum"), precio=("precio_lista", "first"), descuento=("Discount", "first"))
    .reset_index()
    .rename(columns={"Product Name": "producto"})
)
lineas_de_orden = dict(tuple(lineas.groupby("Order ID")))

ordenes = (
    df[["Order ID", "Order Date", "Ship Date", "Ship Mode", "Customer ID"]].drop_duplicates()
    .sort_values(["Order Date", "Order ID"])
    .rename(columns={
        "Order ID": "id_csv", "Order Date": "fecha_orden", "Ship Date": "fecha_envio",
        "Ship Mode": "modo_envio", "Customer ID": "cliente",
    })
)
for orden in ordenes.itertuples(index=False):
    fecha_hora = orden.fecha_orden + timedelta(hours=random.randint(8, 20), minutes=random.randint(0, 59))
    tipo = "ONLINE" if random.random() < PORCENTAJE_ONLINE else "PRESENCIAL"
    region = region_de_cliente[orden.cliente]
    if tipo == "ONLINE":
        sucursal = next(n for n, r, t, *_ in SUCURSALES if r == region and t == "BODEGA")
    else:
        sucursal = random.choice([n for n, r, t, *_ in SUCURSALES if r == region and t == "TIENDA"])

    sql.append(f"\n-- {orden.id_csv}\n")
    sql.append(insert(
        "compra", ["fecha_hora", "tipo_compra", "id_cliente", "id_sucursal"],
        [[
            fecha(fecha_hora), texto(tipo), id_cliente_sql[orden.cliente],
            buscar_id("sucursal", "id_sucursal", nombre=texto(sucursal)),
        ]],
    ))
    sql.append(insert(
        "detalle_compra", ["id_compra", "id_producto", "cantidad", "precio_unitario", "descuento_aplicado"],
        [
            [
                id_compra, buscar_id("producto", "id_producto", nombre_prod=texto(linea.producto)),
                str(linea.cantidad), f"{linea.precio:.2f}", f"{linea.descuento * 100:.2f}",
            ]
            for linea in lineas_de_orden[orden.id_csv].itertuples(index=False)
        ],
    ))
    if tipo == "ONLINE":
        esperada = fecha_hora + timedelta(days=DIAS_ESPERADOS[orden.modo_envio])
        entrega = fecha_hora + (orden.fecha_envio - orden.fecha_orden)
        sql.append(insert("envio", ["fecha_esperada", "fecha_entrega", "id_compra"], [[fecha(esperada), fecha(entrega), id_compra]]))

sql.append("\n-- Inventario: simulado, de 0 a 199 unidades de cada producto en cada sucursal.\n")
sql.append("-- setseed y el ORDER BY hacen que las cantidades sean las mismas en cada ejecución.\n")
sql.append("SELECT setseed(0.42);\n")
sql.append(
    "INSERT INTO inventario (id_producto, id_sucursal, cantidad)\n"
    "SELECT id_producto, id_sucursal, floor(random() * 200)::int\n"
    "FROM (SELECT p.id_producto, s.id_sucursal FROM producto p CROSS JOIN sucursal s ORDER BY 1, 2) AS pares;\n"
)

sql.append("\nCOMMIT;\n")

RUTA_SQL.write_text("".join(sql), encoding="utf-8")
print(f"Generado {RUTA_SQL}")
