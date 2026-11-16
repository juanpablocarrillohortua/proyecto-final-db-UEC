from pydantic import BaseModel, Field, ConfigDict

class CategoriaSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_categoria: int
    nombre_categoria: str = Field(..., max_length=64)

class SubcategoriaSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_subcategoria: int
    nombre_subcategoria: str = Field(..., max_length=64)
    id_categoria: int

class ProductoSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id_producto: int
    nombre_prod: str = Field(..., max_length=255)
    precio_venta: float = Field(..., ge=0)
    precio_compra: float = Field(..., ge=0)
    id_subcategoria: int
