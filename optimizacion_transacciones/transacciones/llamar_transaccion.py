r"""
Este archivo muestra un ejemplo de llamada a la transaccion.

Usa SQLAlchemy y psycopg para gestionar la conexion de py con la base de datos,
la url viene por el archivo config.py donde se define SQLALCHEMY_DATABASE_URI con
MultiHostUrl que gestiona esa conexion en si mismo.

Para llamarlo en la consola use (con su venv activo)
python optimizacion_transacciones\transacciones\llamar_transaccion.py

o use el siguiente comando para llamarlo con cualesquiera parametros

python optimizacion_transacciones\transacciones\llamar_transaccion.py 100 1 '{"10": [5.0, 1]}' ONLINE
"""

import sys
import json
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from config import settings

engine = create_engine(str(settings.SQLALCHEMY_DATABASE_URI))

carrito = {
    10: (10.00, 2),
    25: (0.00, 3),
}


# isolation_level="AUTOCOMMIT" equivale al autocommit=True de psycopg
# para permitir que el COMMIT interno del procedimiento funcione
# Aca se define asi para evitar que la libreria cre una transaccion y se choque
# con la que crea el procedimiento comprar

def new_purchase(
    id_client: int = 100,
    sucursal_id: int = 1,
    car: dict[int, tuple[float, int]] | None = None,
    purchase_type: str = "PRESENCIAL",
) -> bool:
    if car is None:
        car = {
            10: (10.00, 2),
            25: (0.00, 3),
        }

    if not car:
        raise ValueError("El carrito de compras no puede estar vacío.")

    try:
        with engine.connect().execution_options(
            isolation_level="AUTOCOMMIT"
        ) as conn:
            conn.execute(
                text(
                    "CALL comprar(:cliente, :sucursal, CAST(:productos AS jsonb), :tipo);"
                ),
                {
                    "cliente": id_client,
                    "sucursal": sucursal_id,
                    "productos": json.dumps(car),
                    "tipo": purchase_type,
                },
            )
        print("Ejecucion exitosa.")
        return True

    except SQLAlchemyError as e:
        print(f"Error al procesar la compra: {e.orig}")
        return False

# llamada de ejemplo de la funcion desde terminal
if __name__ == "__main__":

    if len(sys.argv) == 1:
        new_purchase()

    # python optimizacion_transacciones\transacciones\llamar_transaccion.py 100 1 '{"10": [5.0, 1]}' ONLINE
    else:
        cliente = int(sys.argv[1])
        sucursal = int(sys.argv[2])
        carrito_raw = json.loads(sys.argv[3])
        carrito = {int(k): tuple(v) for k, v in carrito_raw.items()}
        tipo = sys.argv[4] if len(sys.argv) > 4 else "PRESENCIAL"

        new_purchase(cliente, sucursal, carrito, tipo)
