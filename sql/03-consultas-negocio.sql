-- Paso 4. Consultas SQL equivalentes a las MDX del cubo (para contrastar resultados).
-- Utilidad = SalesAmount - TotalProductCost. "Ventas" = Internet + Reseller.
USE AdventureWorksDW2022;
GO
-- P1. Categorías y subcategorías con mayor volumen de ventas por año, y variación por trimestre
WITH v AS (
  SELECT ProductKey, OrderDateKey, SalesAmount FROM dbo.FactInternetSales
  UNION ALL
  SELECT ProductKey, OrderDateKey, SalesAmount FROM dbo.FactResellerSales)
SELECT d.CalendarYear AS anio, d.CalendarQuarter AS trimestre,
       ISNULL(c.EnglishProductCategoryName, 'Sin asignar')    AS categoria,
       ISNULL(s.EnglishProductSubcategoryName, 'Sin asignar') AS subcategoria,
       SUM(v.SalesAmount) AS ventas
FROM v
JOIN dbo.DimDate d ON d.DateKey = v.OrderDateKey
JOIN dbo.DimProduct p ON p.ProductKey = v.ProductKey
LEFT JOIN dbo.DimProductSubcategory s ON s.ProductSubcategoryKey = p.ProductSubcategoryKey
LEFT JOIN dbo.DimProductCategory c ON c.ProductCategoryKey = s.ProductCategoryKey
GROUP BY d.CalendarYear, d.CalendarQuarter, c.EnglishProductCategoryName, s.EnglishProductSubcategoryName
ORDER BY anio, trimestre, ventas DESC;
GO
-- P2. Territorios más rentables y comparación Internet vs Reseller
SELECT t.SalesTerritoryRegion AS territorio,
       SUM(x.utilidad) AS utilidad_total,
       SUM(CASE WHEN x.canal = 'Internet' THEN x.utilidad END) AS utilidad_internet,
       SUM(CASE WHEN x.canal = 'Reseller' THEN x.utilidad END) AS utilidad_reseller,
       SUM(CASE WHEN x.canal = 'Internet' THEN x.ventas END)   AS ventas_internet,
       SUM(CASE WHEN x.canal = 'Reseller' THEN x.ventas END)   AS ventas_reseller
FROM (
  SELECT 'Internet' AS canal, SalesTerritoryKey, SalesAmount AS ventas, SalesAmount - TotalProductCost AS utilidad FROM dbo.FactInternetSales
  UNION ALL
  SELECT 'Reseller', SalesTerritoryKey, SalesAmount, SalesAmount - TotalProductCost FROM dbo.FactResellerSales) x
JOIN dbo.DimSalesTerritory t ON t.SalesTerritoryKey = x.SalesTerritoryKey
GROUP BY t.SalesTerritoryRegion
ORDER BY utilidad_total DESC;
GO
-- P3. Los 10 productos más rentables y su venta por año y trimestre
WITH v AS (
  SELECT ProductKey, OrderDateKey, SalesAmount, SalesAmount - TotalProductCost AS utilidad FROM dbo.FactInternetSales
  UNION ALL
  SELECT ProductKey, OrderDateKey, SalesAmount, SalesAmount - TotalProductCost FROM dbo.FactResellerSales),
top10 AS (
  SELECT TOP (10) p.EnglishProductName AS producto, SUM(v.utilidad) AS utilidad_total, SUM(v.SalesAmount) AS ventas_total
  FROM v JOIN dbo.DimProduct p ON p.ProductKey = v.ProductKey
  GROUP BY p.EnglishProductName ORDER BY SUM(v.utilidad) DESC)
SELECT * FROM top10 ORDER BY utilidad_total DESC;
GO
WITH v AS (
  SELECT ProductKey, OrderDateKey, SalesAmount, SalesAmount - TotalProductCost AS utilidad FROM dbo.FactInternetSales
  UNION ALL
  SELECT ProductKey, OrderDateKey, SalesAmount, SalesAmount - TotalProductCost FROM dbo.FactResellerSales),
top10 AS (
  SELECT TOP (10) p.EnglishProductName AS producto
  FROM v JOIN dbo.DimProduct p ON p.ProductKey = v.ProductKey
  GROUP BY p.EnglishProductName ORDER BY SUM(v.utilidad) DESC)
SELECT p.EnglishProductName AS producto, d.CalendarYear AS anio, d.CalendarQuarter AS trimestre, SUM(v.SalesAmount) AS ventas
FROM v JOIN dbo.DimProduct p ON p.ProductKey = v.ProductKey JOIN dbo.DimDate d ON d.DateKey = v.OrderDateKey
WHERE p.EnglishProductName IN (SELECT producto FROM top10)
GROUP BY p.EnglishProductName, d.CalendarYear, d.CalendarQuarter
ORDER BY producto, anio, trimestre;
GO
