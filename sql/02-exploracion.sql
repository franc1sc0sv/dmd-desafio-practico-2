-- Paso 2. Exploración de datos: qué tablas existen y cuáles son relevantes.
USE AdventureWorksDW2022;
GO
-- 2.1 Tablas de hechos y dimensiones con su número de filas
SELECT t.name AS tabla,
       CASE WHEN t.name LIKE 'Fact%' THEN 'Hechos' WHEN t.name LIKE 'Dim%' THEN 'Dimension' ELSE 'Otra' END AS tipo,
       SUM(p.rows) AS filas
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name ORDER BY tipo, filas DESC;
GO
-- 2.2 Tablas elegidas para el análisis
SELECT 'FactInternetSales' AS tabla, COUNT(*) AS filas, MIN(OrderDateKey) AS desde, MAX(OrderDateKey) AS hasta FROM dbo.FactInternetSales
UNION ALL SELECT 'FactResellerSales', COUNT(*), MIN(OrderDateKey), MAX(OrderDateKey) FROM dbo.FactResellerSales
UNION ALL SELECT 'DimDate', COUNT(*), MIN(DateKey), MAX(DateKey) FROM dbo.DimDate
UNION ALL SELECT 'DimProduct', COUNT(*), NULL, NULL FROM dbo.DimProduct
UNION ALL SELECT 'DimProductSubcategory', COUNT(*), NULL, NULL FROM dbo.DimProductSubcategory
UNION ALL SELECT 'DimProductCategory', COUNT(*), NULL, NULL FROM dbo.DimProductCategory
UNION ALL SELECT 'DimSalesTerritory', COUNT(*), NULL, NULL FROM dbo.DimSalesTerritory;
GO
-- 2.3 Llaves que unen los hechos con las dimensiones elegidas
SELECT fk.name AS relacion, OBJECT_NAME(fk.parent_object_id) AS tabla_hechos, OBJECT_NAME(fk.referenced_object_id) AS dimension
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) IN ('FactInternetSales','FactResellerSales')
  AND OBJECT_NAME(fk.referenced_object_id) IN ('DimDate','DimProduct','DimSalesTerritory')
ORDER BY tabla_hechos, dimension;
GO
-- 2.4 Calidad: productos sin subcategoría y llaves huérfanas
SELECT COUNT(*) AS productos_sin_subcategoria FROM dbo.DimProduct WHERE ProductSubcategoryKey IS NULL;
SELECT (SELECT COUNT(*) FROM dbo.FactInternetSales f LEFT JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey WHERE p.ProductKey IS NULL) AS internet_sin_producto,
       (SELECT COUNT(*) FROM dbo.FactResellerSales f LEFT JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey WHERE p.ProductKey IS NULL) AS reseller_sin_producto;
GO
