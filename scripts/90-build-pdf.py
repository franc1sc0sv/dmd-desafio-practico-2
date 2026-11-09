"""Genera docs/Desafio-Practico-2.pdf (WeasyPrint) con portada, 8 secciones, capturas anotadas y análisis.

Uso: uv run --with weasyprint --with pillow --with numpy python scripts/90-build-pdf.py
"""
import html, json, os, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from evidencias import SPEC
import weasyprint

NOMBRE = "Francisco Josué Hernández Meléndez"
CARNE = "HM242655"
REPO = "https://github.com/franc1sc0sv/dmd-desafio-practico-2"
FECHA = "15 de noviembre de 2026 (fecha de entrega)"
ANOT = os.path.join(ROOT, "evidencias", "anotadas")
TMP = os.path.join(ROOT, "docs", ".tmp")
os.makedirs(TMP, exist_ok=True)
CIRC = "①②③④⑤⑥⑦⑧"
e = html.escape


def jpg(name, maxw):
    src = os.path.join(ANOT, name + ".png")
    out = os.path.join(TMP, name + ".jpg")
    im = Image.open(src).convert("RGB")
    if im.width > maxw:
        im = im.resize((maxw, int(im.height * maxw / im.width)), Image.LANCZOS)
    im.save(out, quality=86)
    return "file://" + out


def fig(key):
    s = SPEC[key]
    marks = "".join(f'<li><b class="n">{CIRC[i]}</b> {e(m[2])}</li>' for i, m in enumerate(s["marks"]))
    return f'''<section class="fig"><h3>{e(s["titulo"])}</h3><p>{e(s["texto"])}</p>
<div class="par"><div><div class="cap">Escritorio completo</div><img src="{jpg(key, 2000)}"></div>
<div><div class="cap">Detalle ampliado</div><img src="{jpg(key + "-detalle", 1800)}"></div></div>
<ol class="leg">{marks}</ol></section>'''


def code(path, lang=""):
    t = open(os.path.join(ROOT, path), encoding="utf-8-sig").read().strip()
    return f'<div class="cb"><div class="cap">{e(path)}</div><pre>{e(t)}</pre></div>'


def table(head, rows, cls=""):
    th = "".join(f"<th>{e(h)}</th>" for h in head)
    tr = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f'<table class="{cls}"><tr>{th}</tr>{tr}</table>'


S = []
# ---------------- Portada
S.append(f'''<section class="portada"><img class="logo" src="file://{ROOT}/docs/assets/logo-udb.png">
<div class="u">UNIVERSIDAD DON BOSCO</div><div class="v">UDB Virtual · El Salvador</div>
<div class="a">Datawarehouse y Minería de Datos</div>
<h1>DESAFÍO PRÁCTICO 2</h1><h2>Del cubo OLAP al dashboard: convertir datos en decisiones de negocio</h2>
<div class="caso">Caso Adventure Works Cycles · Restauración · Cubo OLAP · Consultas SQL/MDX · Power BI</div>
<div class="et">ESTUDIANTE</div>
<table class="pt"><tr><th>Nombre completo</th><th>Carné</th></tr><tr><td>{e(NOMBRE)}</td><td>{e(CARNE)}</td></tr></table>
<table class="pi"><tr><td><b>Asignatura</b></td><td>Datawarehouse y Minería de Datos (DMD 941), grupo 02T</td></tr>
<tr><td><b>Actividad</b></td><td>Desafío Práctico 2 (20 %)</td></tr>
<tr><td><b>Docente</b></td><td><i>Ing. Katherine Vigil</i></td></tr>
<tr><td><b>Fecha de entrega</b></td><td><i>15 de noviembre de 2026</i></td></tr>
<tr><td><b>Repositorio</b></td><td>{e(REPO)}</td></tr></table>
<div class="nota">San Salvador, El Salvador · noviembre de 2026</div></section>''')
S.append('''<section class="idx"><h2>Contenido</h2><ol>
<li>Portada formal (primera página)</li><li>Restauración de la base de datos</li><li>Exploración de datos</li>
<li>Diseño y procesamiento del cubo OLAP</li><li>Consultas SQL/MDX y resultados</li><li>Visualización en Power BI</li>
<li>Análisis de datos</li><li>Enlace al repositorio de GitHub</li></ol>
<h3>Resumen</h3>
<p>Se restauró AdventureWorksDW2022 en SQL Server 2025, se construyó y procesó un cubo OLAP en Analysis Services (3 dimensiones y 2 grupos de medidas),
se respondieron las 3 preguntas de negocio con consultas SQL y MDX, y se conectó Power BI en vivo al cubo con un dashboard de 3 páginas.
Todos los scripts, el proyecto del cubo y el archivo de Power BI están en el repositorio.</p></section>''')

# ---------------- 1 (portada ya hecha) / 2 Restauración
S.append('<h2 class="sec">2. Restauración de la base de datos</h2>')
S.append('''<p>Se descargó el respaldo oficial <b>AdventureWorksDW2022.bak</b> (≈ 97 MB) de
<i>github.com/Microsoft/sql-server-samples/releases/tag/adventureworks</i>. Es compatible con SQL Server 2025.
Se dejó en una carpeta que el servicio de SQL Server puede leer y se restauró con el script <code>sql/01-restaurar-base.sql</code>,
que mueve los archivos a la carpeta de datos de la instancia.</p>''')
S.append(table(["Paso", "Qué se hizo", "Evidencia"], [
    ["1", "Instalar y comprobar el entorno (SQL Server, SSAS, Visual Studio, SSMS, Power BI)", "Figura «Entorno instalado»"],
    ["2", "Ejecutar el script de restauración en SSMS", "Figura «Restauración: mensajes»"],
    ["3", "Verificar que la base está ONLINE", "Figura «Restauración: resultado»"]], "t"))
for k in ("05-entorno-instalado", "10-ssms-restauracion-mensajes", "11-ssms-restauracion-resultado"):
    S.append(fig(k))
S.append(code("sql/01-restaurar-base.sql"))

# ---------------- 3 Exploración
S.append('<h2 class="sec">3. Exploración de datos</h2>')
S.append('''<p>AdventureWorksDW2022 tiene 31 tablas. Para las tres preguntas de negocio hacen falta las ventas, el tiempo, el producto y el territorio.
Se eligieron estas tablas:</p>''')
S.append(table(["Tabla", "Tipo", "Filas", "Por qué es relevante"], [
    ["FactInternetSales", "Hechos", "60 398", "Ventas por Internet: monto, costo y cantidad (pregunta 2 y 3)."],
    ["FactResellerSales", "Hechos", "60 855", "Ventas por revendedor: se compara con Internet (pregunta 2)."],
    ["DimDate", "Dimensión", "3 652", "Año, trimestre y mes para ver la evolución (preguntas 1 y 3)."],
    ["DimProduct", "Dimensión", "606", "Nombre del producto (pregunta 3) y llave a la subcategoría."],
    ["DimProductSubcategory", "Dimensión", "37", "Subcategorías (pregunta 1)."],
    ["DimProductCategory", "Dimensión", "4", "Categorías (pregunta 1)."],
    ["DimSalesTerritory", "Dimensión", "11", "Territorios de venta (pregunta 2)."]], "t"))
S.append('''<p><b>Calidad de los datos.</b> Las ventas van de diciembre de 2010 a enero de 2014: 2010 y 2014 son años incompletos.
Hay 209 productos sin subcategoría, pero ninguno tiene ventas, así que no cambian los resultados. No hay ventas con producto inexistente.
La utilidad se calcula como <i>monto de ventas − costo total del producto</i>.</p>''')
S.append(fig("12-ssms-exploracion-datos"))
S.append(code("sql/02-exploracion.sql"))

# ---------------- 4 Cubo
S.append('<h2 class="sec">4. Diseño y procesamiento del cubo OLAP</h2>')
S.append('''<p>El cubo se llama <b>Ventas AdventureWorks</b> y vive en la base de Analysis Services <b>AdventureWorksCubo</b>.
Se creó con el script <code>scripts/30-build-cube.ps1</code> (librería AMO) y se exportó a un proyecto de Visual Studio
(<code>cubo/AdventureWorksCubo.sln</code>) para poder verlo y editarlo en el diseñador.</p>''')
S.append(table(["Elemento", "Detalle"], [
    ["Origen de datos", "AdventureWorksDW2022 en localhost (cuenta de servicio de SSAS con permiso de lectura)."],
    ["Vista del origen", "7 tablas con sus relaciones; columna calculada <i>NombreTrimestre</i> («2013 T1»)."],
    ["Dimensión Fecha", "Año &gt; Trimestre &gt; Mes."],
    ["Dimensión Producto", "Categoría &gt; Subcategoría &gt; Producto. Los productos sin subcategoría quedan en «Sin asignar»."],
    ["Dimensión Territorio de Ventas", "Grupo &gt; País &gt; Región."],
    ["Grupos de medidas", "Ventas por Internet y Ventas por Revendedor: monto de ventas, costo del producto y cantidad."],
    ["Medidas calculadas", "Internet Utilidad, Reseller Utilidad, Total Ventas, Utilidad Total, y Utilidad/Ventas Top 10 (conjunto «Top 10 Productos»)."],
    ["Procesamiento", "Despliegue y procesamiento desde Visual Studio (Deploy succeeded) y estado Processed en el servidor."]], "t"))
for k in ("30-vs-explorador-de-soluciones", "34-vs-vista-origen-datos", "31-vs-dimension-fecha", "32-vs-dimension-producto",
          "33-vs-dimension-territorio", "35-vs-cubo-estructura", "36-vs-output-despliegue-exitoso"):
    S.append(fig(k))
S.append('<h3>Cálculos del cubo (MDX)</h3><pre>' + e("""CREATE MEMBER CURRENTCUBE.[Measures].[Internet Utilidad] AS [Internet Monto de Ventas] - [Internet Costo del Producto];
CREATE MEMBER CURRENTCUBE.[Measures].[Reseller Utilidad] AS [Reseller Monto de Ventas] - [Reseller Costo del Producto];
CREATE MEMBER CURRENTCUBE.[Measures].[Total Ventas]   AS [Internet Monto de Ventas] + [Reseller Monto de Ventas];
CREATE MEMBER CURRENTCUBE.[Measures].[Utilidad Total] AS [Internet Utilidad] + [Reseller Utilidad];
CREATE SET    CURRENTCUBE.[Top 10 Productos] AS TOPCOUNT([Producto].[Nombre del Producto].[Nombre del Producto].MEMBERS, 10, [Measures].[Utilidad Total]);""") + '</pre>')

# ---------------- 5 Consultas
S.append('<h2 class="sec">5. Consultas SQL/MDX y resultados</h2>')
S.append('<p>Cada pregunta se resolvió dos veces: con <b>SQL</b> sobre las tablas y con <b>MDX</b> sobre el cubo. Las cifras coinciden, lo que valida el cubo.</p>')
S.append('<h3 class="q">Pregunta 1 · ¿Qué categorías y subcategorías venden más por año y cómo varía trimestre a trimestre?</h3>')
S.append(code("sql/03a-p1-categorias-por-anio-trimestre.sql")); S.append(fig("13-ssms-sql-p1"))
S.append(code("mdx/q1-categorias-por-anio-trimestre.mdx")); S.append(fig("20-mdx-p1-trimestres"))
S.append(code("mdx/q1b-subcategorias-por-anio.mdx")); S.append(fig("21-mdx-p1-anios"))
S.append(code("mdx/q1c-subcategorias-por-trimestre.mdx")); S.append(fig("25-mdx-p1-subcat-trimestres"))
S.append('<p><b>Aporta:</b> Bicicletas es la categoría dominante en todos los años; Road Bikes (43,88 M) y Mountain Bikes (36,45 M) son las subcategorías con más ventas. Por trimestre, en 2013 las bicicletas se mantienen estables (Mountain Bikes sube de $3,60 M a $3,67 M entre T1 y T4), mientras que Road Frames pasa de $0,62 M en T1 a $0,21 M en T4 y Mountain Frames de $0,74 M a $0,42 M.</p>')
S.append('<h3 class="q">Pregunta 2 · ¿Qué territorios son más rentables y cómo se comparan Internet y Revendedor?</h3>')
S.append(code("sql/03b-p2-territorios-internet-vs-reseller.sql")); S.append(fig("14-ssms-sql-p2"))
S.append(code("mdx/q2-territorios-internet-vs-reseller.mdx")); S.append(fig("22-mdx-p2-territorios"))
S.append('<p><b>Aporta:</b> Australia (3,58 M, margen 33,57 %), Southwest (2,36 M, 9,74 %) y Northwest (1,74 M, 10,82 %) lideran en utilidad; en margen sobre ventas también destaca Alemania (22,06 %) y el Reino Unido (18,21 %), mientras que Central, Southeast y Northeast quedan bajo 2 %. La utilidad de Internet es alta en todos; la de Revendedor es casi cero o negativa en varios.</p>')
S.append('<h3 class="q">Pregunta 3 · ¿Cuáles son los 10 productos más rentables y cómo se distribuye su venta en el tiempo?</h3>')
S.append(code("sql/03c-p3-top10-productos.sql")); S.append(fig("15-ssms-sql-p3"))
S.append(code("mdx/q3-top10-productos.mdx")); S.append(fig("23-mdx-p3-top10"))
S.append(code("mdx/q3b-top10-por-anio-trimestre.mdx")); S.append(fig("24-mdx-p3-top10-trimestres"))
S.append('<p><b>Aporta:</b> el producto más rentable es Mountain-200 Black, 38 (872 822 de utilidad). Los 10 primeros son 6 variantes de Mountain-200 y 4 de Road-150 Red.</p>')

S.append('<h3>Optimización de las consultas</h3>')
S.append('''<p>Las consultas SQL se midieron con <code>SET STATISTICS IO, TIME ON</code> (datos en memoria, 0 lecturas físicas). Decisiones de diseño:</p>
<ul>
<li>Cada tabla de hechos se lee <b>una sola vez</b> (un <code>UNION ALL</code> de las columnas necesarias y un solo <code>GROUP BY</code>), en lugar de una consulta por canal.</li>
<li>Solo se leen las columnas que se usan; los cruces son por llaves enteras (<code>ProductKey</code>, <code>OrderDateKey</code>, <code>SalesTerritoryKey</code>).</li>
<li><code>LEFT JOIN</code> y <code>ISNULL</code> solo donde hay productos sin subcategoría, para no perder filas.</li>
<li>En MDX, <code>NON EMPTY</code> evita calcular celdas vacías, y las utilidades y el Top 10 son miembros calculados y un conjunto con nombre del propio cubo, que trabaja sobre datos ya agregados.</li>
</ul>''')
S.append(table(["Consulta", "Filas", "Lecturas lógicas", "Tiempo (CPU / total)"], [
    ["P1 · categorías y subcategorías por año y trimestre", "262", "3 248 (una pasada por cada hecho)", "78 ms / 297 ms"],
    ["P2 · territorios, Internet frente a Revendedor", "10", "2 952", "0 ms / 83 ms"],
    ["P3 · Top 10 productos por utilidad", "10", "3 185", "32 ms / 46 ms"],
    ["P3 · distribución del Top 10 por año y trimestre", "74", "7 405", "77 ms / 70 ms"]], "t"))
S.append('<p>P1, P2 y el Top 10 leen cada tabla de hechos (60 mil filas) una sola vez; la distribución del Top 10 la lee dos veces (una para elegir los 10 productos y otra para repartir su venta). No se creó ningún índice adicional: con este volumen todas responden en menos de 0,3 segundos.</p>')

# ---------------- 6 Power BI
S.append('<h2 class="sec">6. Visualización en Power BI</h2>')
S.append('''<p>Power BI Desktop se conectó <b>en vivo</b> (Connect live) al cubo: no copia datos, cada visual consulta a Analysis Services.
El archivo es <code>powerbi/Dashboard-AdventureWorks.pbix</code> y tiene una página por pregunta.</p>''')
for k in ("p-01-dialogo-conexion", "p-02-credenciales", "p-03-navegador-cubo", "40-powerbi-1-pagina1-categorias-trimestres",
          "40-powerbi-2-pagina2-territorios", "40-powerbi-3-pagina3-top10-productos"):
    S.append(fig(k))

# ---------------- 7 Análisis
S.append('<h2 class="sec">7. Análisis de datos</h2><h3>¿Qué le dicen estos datos a la gerencia?</h3>')
S.append(table(["Indicador", "Valor"], [
    ["Ventas totales (dic. 2010 – ene. 2014)", "$109,81 M"], ["Utilidad total", "$12,55 M (margen 11,43 %)"],
    ["Ventas por Internet", "$29,36 M · utilidad $12,08 M · margen 41,15 %"],
    ["Ventas por Revendedor", "$80,45 M · utilidad $0,47 M · margen 0,58 %"],
    ["Ventas por año", "2011: $25,27 M · 2012: $34,04 M (+34,7 %) · 2013: $49,93 M (+46,7 %)"],
    ["Ventas por categoría", "Bicicletas $94,62 M (86 %) · Componentes $11,80 M · Ropa $2,12 M · Accesorios $1,27 M"],
    ["Top 10 productos", "53,44 % de la utilidad con 26,28 % de las ventas"]], "t"))
S.append('''<ol class="an">
<li><b>La empresa crece fuerte.</b> Las ventas subieron 34,7 % en 2012 y 46,7 % en 2013. 2010 y 2014 son años incompletos y no se comparan.</li>
<li><b>El negocio son las bicicletas.</b> Bicicletas es el 86 % de las ventas; Road Bikes y Mountain Bikes juntas pasan de $80 M. Accesorios y Ropa son pequeños pero crecen: los accesorios vendieron 7 veces más en 2013 que en 2012.</li>
<li><b>El canal Revendedor vende mucho y gana casi nada.</b> Aporta el 73 % de las ventas pero solo el 3,7 % de la utilidad (margen 0,58 %). Internet vende menos, pero deja 41 centavos de utilidad por dólar. En Australia, Alemania, Francia y Southwest la utilidad de Revendedor es negativa. Conviene revisar precios, descuentos y costos de ese canal.</li>
<li><b>Australia es el territorio más rentable</b> ($3,58 M), casi todo por Internet. Los territorios de Estados Unidos (Central, Southeast, Northeast) venden mucho por revendedor pero dejan menos de $0,15 M cada uno.</li>
<li><b>Pocos productos sostienen la utilidad.</b> Diez productos dan el 53 % de la utilidad. La Road-150 Red se vende hasta 2011 T4 y la Mountain-200 aparece en 2011 T4 y sigue hasta 2013 T4: una reemplaza a la otra. Hay riesgo si el modelo actual se agota sin sucesor.</li>
</ol>
<p><b>Recomendaciones:</b> (1) revisar la política de precios y descuentos del canal Revendedor; (2) impulsar Internet en los territorios donde ya rinde; (3) preparar un sucesor de la Mountain-200; (4) seguir de cerca accesorios y ropa, que crecen rápido.</p>
<p class="peq"><b>Límites.</b> La utilidad es monto de ventas menos costo del producto del almacén de datos; no incluye gastos de operación. Los datos llegan hasta el 28 de enero de 2014.</p>''')

# ---------------- 8 Repo
S.append(f'''<h2 class="sec">8. Enlace al repositorio de GitHub</h2>
<p><b>{e(REPO)}</b></p>
{table(["Carpeta", "Contenido"], [
  ["docs/", "Este documento en PDF."], ["sql/", "Restauración, exploración y consultas de negocio."],
  ["mdx/", "Consultas sobre el cubo."], ["cubo/", "Proyecto de Visual Studio (solución, dimensiones, cubo, origen y vista de datos)."],
  ["powerbi/", "Dashboard-AdventureWorks.pbix y el generador."], ["scripts/", "Instalación, construcción del cubo, capturas y generación del PDF."],
  ["evidencias/", "Capturas crudas y anotadas (recuadros numerados)."]], "t")}''')

CSS = """
@page { size: letter portrait; margin: 16mm 14mm 14mm 14mm; @top-right { content: counter(page); font-size: 10pt; color: #333; } }
@page :first { @top-right { content: ""; } }
body { font-family: 'Carlito', 'Calibri', 'DejaVu Sans', sans-serif; font-size: 9.3pt; color: #1b1b1b; line-height: 1.36; }
h1 { font-size: 34pt; margin: 8mm 0 2mm; color: #1F4E79; } h2 { font-size: 15pt; color: #1F4E79; }
h2.sec { font-size: 18pt; border-bottom: 3px solid #1F4E79; padding-bottom: 2mm; margin: 0 0 4mm; page-break-before: always; }
h3 { font-size: 11.5pt; margin: 5mm 0 1.5mm; color: #1F4E79; } h3.q { background: #eaf0fb; padding: 2mm 3mm; border-left: 4px solid #1F4E79; break-after: avoid; }
.portada { text-align: center; padding-top: 8mm; } .portada .logo { width: 28mm; } .portada .u { font-size: 17pt; font-weight: bold; color: #1F4E79; margin-top: 3mm; }
.portada .v { font-size: 9.5pt; color: #666; } .portada .a { font-size: 12pt; margin-top: 10mm; color: #444; }
.portada h1 { font-size: 26pt; margin: 6mm 0 1mm; } .portada h2 { font-size: 14pt; font-weight: bold; color: #111; margin: 0; }
.portada .caso { margin: 3mm 0 10mm; font-size: 9pt; color: #777; } .portada .et { text-align: left; font-weight: bold; color: #1F4E79; font-size: 10pt; margin: 0 14mm 1mm; }
.portada .nota { margin-top: 16mm; color: #888; font-size: 9pt; }
table.pt, table.pi { width: auto; margin: 0 14mm 5mm; font-size: 10pt; text-align: left; } table.pt { width: 160mm; } table.pt th { padding: 2.4mm 3mm; }
table.pt td { border: none; border-bottom: 1px solid #ddd; background: none !important; padding: 2.4mm 3mm; } table.pi td { border: none; background: none !important; padding: 2.4mm 3mm; } table.pi td:first-child { width: 42mm; }
table { border-collapse: collapse; width: 100%; margin: 2mm 0 4mm; } th { background: #1F4E79; color: white; text-align: left; }
th, td { border: 1px solid #c9d1e3; padding: 1.4mm 2.4mm; vertical-align: top; } tr:nth-child(even) td { background: #f5f7fc; }

.idx { page-break-before: always; } .fig { page-break-inside: avoid; margin: 0 0 6mm; }
.fig h3 { margin-top: 0; } .par { display: block; } .par > div { margin-bottom: 2mm; } .par img { width: 100%; border: 1px solid #bbb; }
.cap { font-size: 7.5pt; color: #666; margin: 1mm 0; } .leg { margin: 1mm 0; padding-left: 0; list-style: none; font-size: 9pt; columns: 1; }
.leg li { margin: 0 0 1mm; break-inside: avoid; } b.n { color: #dc141e; font-size: 12pt; }
div.cb { break-inside: avoid; } pre { background: #f3f4f7; border: 1px solid #d7dbe6; padding: 2mm; font-size: 7.4pt; line-height: 1.25; white-space: pre-wrap; margin: 0 0 3mm; }
code { background: #f0f2f7; padding: 0 1mm; font-size: 8.6pt; } .aviso { background: #fff6dd; border: 1px solid #e3c56b; padding: 3mm; margin: 3mm 0; }
.an li { margin-bottom: 2mm; } .peq { font-size: 8.5pt; color: #555; }
"""
doc = "<html><head><meta charset='utf-8'><style>" + CSS + "</style></head><body>" + "".join(S) + "</body></html>"
out = os.path.join(ROOT, "docs", "Desafio-Practico-2.pdf")
open(os.path.join(ROOT, "docs", ".tmp", "doc.html"), "w", encoding="utf-8").write(doc)
weasyprint.HTML(string=doc, base_url=ROOT).write_pdf(out)
print("PDF:", out, round(os.path.getsize(out) / 1e6, 1), "MB")
