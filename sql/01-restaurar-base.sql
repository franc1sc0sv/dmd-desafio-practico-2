-- Paso 1. Restaurar AdventureWorksDW2022 en SQL Server 2025.
-- Backup oficial: https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks
-- Cambia @bak por la ruta donde dejaste el .bak (debe poder leerla el servicio de SQL Server).
DECLARE @bak  nvarchar(260) = N'C:\Users\Public\dp2\AdventureWorksDW2022.bak';
DECLARE @data nvarchar(260) = CONVERT(nvarchar(260), SERVERPROPERTY('InstanceDefaultDataPath'));
DECLARE @sql  nvarchar(max) = N'
RESTORE DATABASE AdventureWorksDW2022
FROM DISK = N''' + @bak + N'''
WITH MOVE N''AdventureWorksDW2022''     TO N''' + @data + N'AdventureWorksDW2022.mdf'',
     MOVE N''AdventureWorksDW2022_log'' TO N''' + @data + N'AdventureWorksDW2022_log.ldf'',
     REPLACE, STATS = 25;';
EXEC sys.sp_executesql @sql;
GO
-- Verificacion
SELECT name, state_desc, compatibility_level, create_date FROM sys.databases WHERE name = N'AdventureWorksDW2022';
GO
