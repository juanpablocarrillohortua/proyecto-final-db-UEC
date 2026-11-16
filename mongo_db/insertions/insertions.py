from sqlalchemy import create_engine, text
from pymongo import MongoClient
from pymongo.errors import BulkWriteError
from schemas import CategoriaSchema, SubcategoriaSchema, ProductoSchema

from config import settings

# 1. Conexiones (ajusta tus credenciales de PostgreSQL y MongoDB)
PG_URI = str(settings.SQLALCHEMY_DATABASE_URI)
MONGO_URI = str(settings.MONGO_DATABASE_URI)

pg_engine = create_engine(PG_URI)
mongo_client = MongoClient(MONGO_URI)
mongo_db = mongo_client[settings.MONGO_DB]

def migrar_tabla(query: str, schema_cls, collection_name: str):
    print(f"Extrayendo datos para '{collection_name}'...")

    with pg_engine.connect() as conn:
        result = conn.execute(text(query))
        # Convertimos cada fila de SQLAlchemy a diccionario y validamos con Pydantic
        documentos_validados = [
            schema_cls.model_validate(dict(row._mapping)).model_dump()
            for row in result
        ]

    if not documentos_validados:
        print(f"No hay registros para insertar en '{collection_name}'.")
        return

    try:
        # ordered=False permite que si un ID ya existe (por índice unique), continúe con los demás
        res = mongo_db[collection_name].insert_many(documentos_validados, ordered=False)
        print(f"{len(res.inserted_ids)} documentos insertados en '{collection_name}'.")
    except BulkWriteError as bwe:
        insertados = bwe.details.get("nInserted", 0)
        errores = len(bwe.details.get("writeErrors", []))
        print(f"{collection_name}': {insertados} insertados, {errores} omitidos/duplicados.")

if __name__ == "__main__":
    try:
        # Respetamos el orden lógico de las dependencias
        migrar_tabla(
            query="SELECT id_categoria, nombre_categoria FROM categoria",
            schema_cls=CategoriaSchema,
            collection_name="categorias"
        )

        migrar_tabla(
            query="SELECT id_subcategoria, nombre_subcategoria, id_categoria FROM subcategoria",
            schema_cls=SubcategoriaSchema,
            collection_name="subcategorias"
        )

        migrar_tabla(
            query="SELECT id_producto, nombre_prod, precio_venta, precio_compra, id_subcategoria FROM producto",
            schema_cls=ProductoSchema,
            collection_name="productos"
        )
    finally:
        pg_engine.dispose()
        mongo_client.close()

