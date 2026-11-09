USE AdventureWorksDW2022;
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
