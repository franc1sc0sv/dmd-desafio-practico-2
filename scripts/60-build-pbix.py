"""Genera Dashboard-AdventureWorks.pbix (conexión en vivo al cubo) a partir de plantilla/.

Uso: python3 scripts/60-build-pbix.py [salida.pbix]
Formato PBIR: cada página y cada visual es un JSON. Campos: Entity = dimensión o grupo de medidas.
"""
import hashlib, json, os, shutil, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPL = os.path.join(ROOT, "powerbi", "plantilla")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "powerbi", "Dashboard-AdventureWorks.pbix")
SCH = "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/"


def hid(s):
    return hashlib.sha1(s.encode()).hexdigest()[:20]


def col(entity, prop):
    return {"Column": {"Expression": {"SourceRef": {"Entity": entity}}, "Property": prop}}


def mea(entity, prop):
    return {"Measure": {"Expression": {"SourceRef": {"Entity": entity}}, "Property": prop}}


def proj(field, active=False):
    k = "Column" if "Column" in field else "Measure"
    f = field[k]
    ent, prop = f["Expression"]["SourceRef"]["Entity"], f["Property"]
    p = {"field": field, "queryRef": f"{ent}.{prop}", "nativeQueryRef": prop}
    if active:
        p["active"] = True
    return p


def lit(s):
    return {"expr": {"Literal": {"Value": "'" + s.replace("'", "''") + "'"}}}


def visual(page, key, vtype, x, y, w, h, roles, title, z=0, extra_filters=None, sort=None):
    name = hid(page + key)
    q = {"queryState": {r: {"projections": [proj(f, a) for f, a in fl]} for r, fl in roles.items()}}
    if sort:
        q["sortDefinition"] = {"sort": [{"field": sort, "direction": "Descending"}], "isDefaultSort": False}
    v = {"$schema": SCH + "visualContainer/2.14.0/schema.json", "name": name,
         "position": {"x": x, "y": y, "z": z, "height": h, "width": w, "tabOrder": z},
         "visual": {"visualType": vtype, "query": q,
                    "visualContainerObjects": {"title": [{"properties": {"show": {"expr": {"Literal": {"Value": "true"}}}, "text": lit(title)}}]},
                    "drillFilterOtherVisuals": True}}
    if extra_filters:
        v["filterConfig"] = {"filters": extra_filters}
    return name, v


def textbox(page, key, x, y, w, h, text, size="22pt", z=0):
    name = hid(page + key)
    return name, {"$schema": SCH + "visualContainer/2.14.0/schema.json", "name": name,
                  "position": {"x": x, "y": y, "z": z, "height": h, "width": w, "tabOrder": z},
                  "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": [
                      {"textRuns": [{"value": text, "textStyle": {"fontWeight": "bold", "fontSize": size}}]}]}}]},
                      "drillFilterOtherVisuals": True}}


def topn(entity, prop, mentity, mprop, n):
    f = col(entity, prop)
    return {"name": hid("top" + prop), "field": f, "type": "TopN",
            "filter": {"Version": 2,
                       "From": [{"Name": "p", "Entity": entity, "Type": 0}, {"Name": "m", "Entity": mentity, "Type": 0}],
                       "Where": [{"Condition": {"In": {
                           "Expressions": [{"Column": {"Expression": {"SourceRef": {"Source": "p"}}, "Property": prop}}],
                           "Table": {"SubqueryExpression": {"Subquery": {
                               "Version": 2, "From": [{"Name": "p1", "Entity": entity, "Type": 0}, {"Name": "m1", "Entity": mentity, "Type": 0}],
                               "Select": [{"Column": {"Expression": {"SourceRef": {"Source": "p1"}}, "Property": prop}, "Name": "field"}],
                               "OrderBy": [{"Direction": 2, "Expression": {"Measure": {"Expression": {"SourceRef": {"Source": "m1"}}, "Property": mprop}}}],
                               "Top": n}}}}}}]}}


M = "Measures"
ANIO, TRIM = col("Fecha", "Año"), col("Fecha", "Trimestre")
CAT, SUB, PROD = col("Producto", "Categoría"), col("Producto", "Subcategoría"), col("Producto", "Nombre del Producto")
REG = col("Territorio de Ventas", "Región")
TV, UT, UI, UR = mea(M, "Total Ventas"), mea(M, "Utilidad Total"), mea(M, "Internet Utilidad"), mea(M, "Reseller Utilidad")
UT10, TV10 = mea(M, "Utilidad Top 10"), mea(M, "Ventas Top 10")
VI, VR = mea("Ventas por Internet", "Internet Monto de Ventas"), mea("Ventas por Revendedor", "Reseller Monto de Ventas")

pages = []
# --- Página 1
p = "p1"; vs = []
vs.append(textbox(p, "h", 20, 10, 1880, 70, "Pregunta 1 · Categorías y subcategorías con más ventas, por año y por trimestre"))
vs.append(visual(p, "a", "columnChart", 20, 90, 940, 470, {"Category": [(ANIO, True)], "Series": [(CAT, False)], "Y": [(TV, False)]}, "Ventas por año y categoría", 1))
vs.append(visual(p, "b", "lineChart", 980, 90, 920, 470, {"Category": [(TRIM, True)], "Series": [(CAT, False)], "Y": [(TV, False)]}, "Ventas por trimestre y categoría", 2))
vs.append(visual(p, "c", "pivotTable", 20, 580, 1880, 490, {"Rows": [(SUB, True)], "Columns": [(ANIO, True)], "Values": [(TV, False)]}, "Subcategorías: ventas por año", 3, sort=TV))
pages.append((p, "P1 · Categorías y trimestres", vs))
# --- Página 2
p = "p2"; vs = []
vs.append(textbox(p, "h", 20, 10, 1880, 70, "Pregunta 2 · Rentabilidad por territorio: Internet frente a Revendedor"))
vs.append(visual(p, "a", "clusteredBarChart", 20, 90, 940, 520, {"Category": [(REG, True)], "Y": [(UI, False), (UR, False)]}, "Utilidad por territorio y canal", 1, sort=UT))
vs.append(visual(p, "b", "clusteredColumnChart", 980, 90, 920, 520, {"Category": [(REG, True)], "Y": [(VI, False), (VR, False)]}, "Ventas por territorio y canal", 2))
vs.append(visual(p, "c", "tableEx", 20, 630, 1400, 440, {"Values": [(REG, False), (UT, False), (UI, False), (UR, False), (VI, False), (VR, False)]}, "Detalle por territorio", 3, sort=UT))
vs.append(visual(p, "d", "card", 1440, 630, 460, 200, {"Values": [(UT, False)]}, "Utilidad total", 4))
vs.append(visual(p, "e", "card", 1440, 850, 460, 200, {"Values": [(TV, False)]}, "Ventas totales", 5))
pages.append((p, "P2 · Territorios", vs))
# --- Página 3 (las medidas "Top 10" solo tienen valor para los 10 productos más rentables)
p = "p3"; vs = []
vs.append(textbox(p, "h", 20, 10, 1880, 70, "Pregunta 3 · Los 10 productos más rentables y su venta por año y trimestre"))
vs.append(visual(p, "a", "clusteredBarChart", 20, 90, 940, 520, {"Category": [(PROD, True)], "Y": [(UT10, False)]}, "Top 10 productos por utilidad", 1))
vs.append(visual(p, "b", "columnChart", 980, 90, 920, 520, {"Category": [(ANIO, True)], "Series": [(PROD, False)], "Y": [(TV10, False)]}, "Ventas por año de los 10 productos", 2))
vs.append(visual(p, "c", "pivotTable", 20, 630, 1880, 440, {"Rows": [(PROD, True)], "Columns": [(TRIM, True)], "Values": [(TV10, False)]}, "Ventas por trimestre de los 10 productos", 3))
pages.append((p, "P3 · Top 10 productos", vs))

work = os.path.join(ROOT, "powerbi", ".build")
shutil.rmtree(work, ignore_errors=True)
shutil.copytree(TPL, work)
os.remove(os.path.join(work, "SecurityBindings"))
ct = os.path.join(work, "[Content_Types].xml")
xml = open(ct, encoding="utf-8-sig").read().replace('<Override PartName="/SecurityBindings" ContentType="" />', "")
open(ct, "w", encoding="utf-8-sig").write(xml)
pdir = os.path.join(work, "Report", "definition", "pages")
os.makedirs(pdir, exist_ok=True)
order = []
for key, title, vs in pages:
    pid = hid("page" + key)
    order.append(pid)
    d = os.path.join(pdir, pid)
    os.makedirs(os.path.join(d, "visuals"), exist_ok=True)
    json.dump({"$schema": SCH + "page/2.1.0/schema.json", "name": pid, "displayName": title,
               "displayOption": "FitToPage", "height": 1080, "width": 1920}, open(os.path.join(d, "page.json"), "w", encoding="utf-8"), ensure_ascii=False)
    for name, v in vs:
        vd = os.path.join(d, "visuals", name)
        os.makedirs(vd, exist_ok=True)
        json.dump(v, open(os.path.join(vd, "visual.json"), "w", encoding="utf-8"), ensure_ascii=False)
json.dump({"$schema": SCH + "pagesMetadata/1.1.0/schema.json", "pageOrder": order, "activePageName": order[0]},
          open(os.path.join(pdir, "pages.json"), "w", encoding="utf-8"))

if os.path.exists(OUT):
    os.remove(OUT)
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    # Mismo orden que escribe Power BI: Version primero y SecurityBindings al final.
    first = ["Version", "[Content_Types].xml", "DiagramLayout", "Settings", "Metadata", "Connections"]
    last = []  # SecurityBindings se omite: es una firma del contenido y Power BI la regenera al guardar
    rest = []
    for base, _, files in os.walk(work):
        for f in sorted(files):
            rel = os.path.relpath(os.path.join(base, f), work).replace(os.sep, "/")
            if rel not in first + last + ["SecurityBindings"]:
                rest.append(rel)
    for rel in first + sorted(rest) + last:
        z.write(os.path.join(work, rel), rel)
shutil.rmtree(work)
print("pbix generado:", OUT, os.path.getsize(OUT), "bytes;", sum(len(v) for _, _, v in pages), "visuales")
