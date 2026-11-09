USE AdventureWorksDW2022;
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
