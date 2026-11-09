# Desafío Práctico 2 · Del cubo OLAP al dashboard

Datawarehouse y Minería de Datos (DMD941) · Universidad Don Bosco · Ing. Katherine Vigil  
Caso: **Adventure Works Cycles**. Estudiante: Francisco Josué Hernández Meléndez.

Se restaura `AdventureWorksDW2022`, se construye y procesa un **cubo OLAP** en Analysis Services y se
visualiza en **Power BI** conectado en vivo al cubo. Responde tres preguntas de negocio:

1. Categorías y subcategorías con más ventas por año, y su variación trimestre a trimestre.
2. Territorios más rentables y comparación Internet frente a Revendedor.
3. Los 10 productos más rentables y su venta por año y trimestre.

📄 **Documento:** [`docs/Desafio-Practico-2.pdf`](docs/Desafio-Practico-2.pdf) (portada, 8 secciones, capturas con recuadros numerados, análisis).

## Contenido

| Carpeta | Qué hay |
|---|---|
| `docs/` | PDF del desafío. |
| `sql/` | `01` restaurar la base · `02` exploración · `03*` consultas de negocio en SQL. |
| `mdx/` | Consultas MDX sobre el cubo (P1, P2, P3). |
| `cubo/` | Proyecto de Visual Studio: `AdventureWorksCubo.sln` (origen, vista, 3 dimensiones, cubo). |
| `powerbi/` | `Dashboard-AdventureWorks.pbix` (conexión en vivo al cubo, 3 páginas) y la plantilla para regenerarlo. |
| `scripts/` | Instalación, construcción del cubo, capturas y generación del PDF. |
| `evidencias/` | Capturas crudas y anotadas (escritorio completo). |

## Modelo del cubo

- **Dimensiones:** Fecha (Año › Trimestre › Mes) · Producto (Categoría › Subcategoría › Producto) · Territorio de Ventas (Grupo › País › Región).
- **Grupos de medidas:** Ventas por Internet y Ventas por Revendedor (monto, costo, cantidad).
- **Cálculos:** Utilidad = monto − costo; Total Ventas; Utilidad Total; conjunto «Top 10 Productos».

## Cómo reproducirlo (Windows 11)

Requisitos: SQL Server 2025 (Developer) con **Analysis Services multidimensional**, Visual Studio 2022 con la extensión
*Analysis Services Projects*, SSMS 22 y Power BI Desktop.
Para desplegar desde Visual Studio contra SQL Server 2025, `scripts/13-vs-amo-swap.ps1` (como administrador) alinea las librerías de Analysis Services de Visual Studio con las del servidor.

1. Descarga `AdventureWorksDW2022.bak` de <https://github.com/Microsoft/sql-server-samples/releases/tag/adventureworks>
   y déjalo en `C:\Users\Public\dp2\`.
2. Copia a `C:\Users\Public\dp2\` los archivos de `scripts/*.ps1`, `sql/*.sql` y la carpeta `mdx/` (como `queries\`).
3. Ejecuta `scripts\run-all.ps1` (añade `-Instalar` para instalar SSAS y la extensión, o `-SinCapturas`).
4. En WSL/Linux: `python3 scripts/60-build-pbix.py`, luego `uv run --with pillow --with numpy python scripts/annotate.py` y
   `uv run --with weasyprint --with pillow --with numpy python scripts/90-build-pdf.py`.

Los `.ps1` se guardan con BOM UTF-8 (sin él, Windows PowerShell 5.1 daña las tildes de los nombres del cubo).

## Resultados clave

Ventas totales $109,81 M · utilidad $12,55 M (11,43 %). Internet: margen 41,15 %; Revendedor: 0,58 %.
Los 10 productos más rentables concentran el 53,44 % de la utilidad.
