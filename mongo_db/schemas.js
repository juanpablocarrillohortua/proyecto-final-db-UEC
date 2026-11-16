db = db.getSiblingDB('product_catalog');

// 1. Crear colecciones (todo en plural para mantener consistencia)
db.createCollection("productos", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["id_producto", "nombre_prod", "precio_venta", "precio_compra", "id_subcategoria"],
      properties: {
        id_producto: {
          bsonType: ["int", "long"],
          description: "Debe ser un entero (BIGINT) y es obligatorio"
        },
        nombre_prod: {
          bsonType: "string",
          maxLength: 128,
          description: "Texto máximo de 64 caracteres (VARCHAR(64)) y obligatorio"
        },
        precio_venta: {
          bsonType: ["double", "decimal", "int"],
          minimum: 0,
          description: "Número positivo obligatorio"
        },
        precio_compra: {
          bsonType: ["double", "decimal", "int"],
          minimum: 0,
          description: "Número positivo obligatorio"
        },
        id_subcategoria: {
          bsonType: ["int", "long"],
          description: "Referencia obligatoria a subcategorias"
        }
      }
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

db.createCollection('subcategorias');
db.createCollection('categorias');




// 2. Crear índices en los campos que harán de "PK" y "FK"
db.categorias.createIndex({ "id_categoria": 1 }, { unique: true });

db.subcategorias.createIndex({ "id_subcategoria": 1 }, { unique: true });
db.subcategorias.createIndex({ "id_categoria": 1 });

db.productos.createIndex({ "id_producto": 1 }, { unique: true });
db.productos.createIndex({ "id_subcategoria": 1 });
