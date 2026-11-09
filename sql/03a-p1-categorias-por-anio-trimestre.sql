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
