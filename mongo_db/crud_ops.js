db = db.getSiblingDB('product_catalog');

// 2. Operaciones de lectura

// Buscar el producto mas caro y su subcategoria

db.productos.aggregate([
    {
        $lookup: {
            from: "subcategorias",
            localField: "id_subcategoria",
            foreignField: "id_subcategoria",
            as: "subcategoria"
        }
    },
    {
        $sort: {
            precio_venta: -1
        }
    },
    {
        $limit: 1
    },
    {
        $unwind: {
      path: "$subcategoria",
      preserveNullAndEmptyArrays: true
        }
    },
    {
        $project: {
            _id:0,
            nombre_prod:1,
            precio_venta:1,
            precio_compra:1,
            nombre_subcategoria:"$subcategoria.nombre_subcategoria"
        }
    }
])

// Cual subcategoria tiene en promedio la mayor ganancia bruta

db.productos.aggregate([
    {
        $group :{
            _id: "$id_subcategoria",
            ganancia_promedio: {
                $avg: {$subtract: ["$precio_venta", "$precio_compra"]}
            }
        }
    },
    {
        $sort: {ganancia_promedio: -1}
    },
    {
        $limit :1
    },
    {
        $lookup: {
            from: "subcategorias",
            localField: "_id",
            foreignField: "id_subcategoria",
            as: "info_subcategoria"
        }
    },
    {
        $unwind: {
            path: "$info_subcategoria",
            preserveNullAndEmptyArrays: true
        }
    },
    {
        $project: {
            _id: 0,
            id_subcategoria: "$_id",
            nombre_subcategoria: "$info_subcategoria.nombre_subcategoria",
            ganancia_promedio: {$round: ["$ganancia_promedio", 2]}
        }
    }
])


// Operaciones de actualizacion

db.productos.updateMany(
  {},
  {
    $mul: {
      precio_venta: 0.5
    }
  }
)

// Operaciones de eliminacion

db.productos.deleteMany({
  precio_venta: { $gt: 1000 }
})
