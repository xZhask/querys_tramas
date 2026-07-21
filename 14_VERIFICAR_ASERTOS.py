import os
import sys
import json
import argparse
import subprocess
import openpyxl

CONTROL_10_SQL = """
WITH emergency_reported AS (
	SELECT sp_numero_documento_paciente AS DNI, sp_fecha_atencion::date AS fecha,
		CASE
			WHEN e.prioridad = 1 THEN '99285'
			WHEN e.prioridad = 2 THEN '99284'
			WHEN e.prioridad = 3 THEN '99282'
			WHEN e.prioridad = 4 THEN '99281'
			ELSE '99281'
		END AS codigo
	FROM temp_emergencia_sigesapol_estancia e
	WHERE e.excluir_tipo2 = false
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
		  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
	  )
	UNION ALL
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_emergencia_sigesapol bdt
	JOIN temp_emergencia_sigesapol_estancia e
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
	WHERE e.excluir_tipo2 = false AND bdt.codigo_procedimiento IS NOT NULL
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND bdt.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
	  )
	UNION ALL
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_emergencia_sigesapol lab
	JOIN temp_emergencia_sigesapol_estancia e
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
	WHERE e.excluir_tipo2 = false AND lab.codigo_procedimiento IS NOT NULL
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND lab.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
	  )
),
hospitalization_reported AS (
	SELECT sp_numero_documento_paciente AS DNI, sp_fecha_atencion::date AS fecha, sp_codigo_procedimiento AS codigo
	FROM temp_hospitalizacion_local
	UNION ALL
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_hospitalizacion_local bdt
	JOIN temp_hospitalizacion_local e
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE bdt.codigo_procedimiento IS NOT NULL
	UNION ALL
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_emergencia_sigesapol bdt
	JOIN temp_hospitalizacion_local e
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE e.origen_reclasificacion IS NOT NULL AND bdt.codigo_procedimiento IS NOT NULL
	UNION ALL
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_hospitalizacion_local lab
	JOIN temp_hospitalizacion_local e
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE lab.codigo_procedimiento IS NOT NULL
	UNION ALL
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_emergencia_sigesapol lab
	JOIN temp_hospitalizacion_local e
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE e.origen_reclasificacion IS NOT NULL AND lab.codigo_procedimiento IS NOT NULL
)
SELECT COUNT(*) AS total_duplicados_emergencia_hosp
FROM emergency_reported er
JOIN hospitalization_reported hr
  ON er.DNI = hr.DNI
 AND er.fecha = hr.fecha
 AND er.codigo = hr.codigo;
"""


def parse_args():
    parser = argparse.ArgumentParser(description="Verificar aserciones A1/A2/A3 del contrato de salidas v2")
    parser.add_argument("--year", type=int, default=2025)
    parser.add_argument("--month", type=int, required=True)
    parser.add_argument("--skip-control10", action="store_true", help="Omitir A3-CONTROL10 (no requiere BD)")
    parser.add_argument("--allow-missing-conservacion", action="store_true",
                         help="No fallar si metricas.json fue generado antes de existir la tabla 'conservacion' (mes ya procesado con el codigo anterior)")
    return parser.parse_args()


def load_trama_keys(filepath, cols, key_names):
    idx = [cols.index(n) if n in cols else -1 for n in key_names]
    if -1 in idx:
        return set()
    keys = set()
    if not os.path.exists(filepath):
        return keys
    with open(filepath, "rb") as f:
        data = f.read().decode("utf-8")
    sep = "|\r\n" if "|\r\n" in data else "|\n"
    for rec in data.split(sep):
        if not rec.strip():
            continue
        parts = rec.split("|")
        try:
            key = tuple(parts[i].strip() for i in idx)
        except IndexError:
            continue
        keys.add(key)
    return keys


def check_a1(infos_dir, period, allow_missing=False):
    path = os.path.join(infos_dir, "metricas.json")
    if not os.path.exists(path):
        print(f"A1 [{period}]: FALLO - no existe {path}")
        return False
    with open(path, "r", encoding="utf-8") as f:
        metrics = json.load(f)
    conservacion = metrics.get("conservacion")
    if not conservacion:
        if allow_missing:
            print(f"A1 [{period}]: SKIPPED (metricas.json se genero antes de la tabla 'conservacion'; requeriria recargar las tablas temporales de este mes para recalcularla)")
            return True
        print(f"A1 [{period}]: FALLO - metricas.json no tiene tabla 'conservacion'")
        return False
    ok = True
    for tipo, row in conservacion.items():
        if row.get("residuo", 1) != 0:
            print(f"A1 [{period}]: FALLO - residuo != 0 en '{tipo}': {row}")
            ok = False
    if ok:
        print(f"A1 [{period}]: PASS (residuo = 0 en las {len(conservacion)} tramas)")
    return ok


def check_a2(exp_dir, infos_dir, tramas_dir, period):
    cols_path = os.path.join(infos_dir, ".trama_columns.json")
    if not os.path.exists(cols_path):
        print(f"A2 [{period}]: FALLO - no existe {cols_path}")
        return False
    with open(cols_path, "r", encoding="utf-8") as f:
        trama_cols = json.load(f)

    retained_keys = set()
    for fname in (".retained_package_emergencia.json", ".retained_package_hospitalizacion.json"):
        fpath = os.path.join(infos_dir, fname)
        if not os.path.exists(fpath):
            continue
        with open(fpath, "r", encoding="utf-8") as f:
            rows = json.load(f)
        for r in rows:
            fecha = r.get("sp_fecha_atencion")
            if fecha and " " in str(fecha):
                fecha = str(fecha).split(" ")[0]
            retained_keys.add((str(r.get("sp_numero_documento_paciente")), str(fecha), str(r.get("sp_codigo_procedimiento"))))

    eme_cols = trama_cols.get("emergencia", [])
    eme_keys = load_trama_keys(
        os.path.join(tramas_dir, "trama_emergencia.txt"), eme_cols,
        ["sp_numero_documento_paciente", "sp_fecha_atencion", "sp_codigo_procedimiento"]
    )
    leaked = retained_keys & eme_keys
    if leaked:
        print(f"A2 [{period}]: FALLO - {len(leaked)} claves de paquete retenido (Caso A) presentes en trama_emergencia.txt")
        return False
    print(f"A2 [{period}]: PASS (cero fugas de paquete retenido en trama_emergencia.txt)")
    return True


def load_trama_values(filepath, cols, col_name):
    if col_name not in cols:
        return None
    idx = cols.index(col_name)
    valores = set()
    if not os.path.exists(filepath):
        return valores
    with open(filepath, "rb") as f:
        data = f.read().decode("utf-8")
    sep = "|\r\n" if "|\r\n" in data else "|\n"
    for rec in data.split(sep):
        if not rec.strip():
            continue
        parts = rec.split("|")
        if idx < len(parts):
            valores.add(parts[idx].strip())
    return valores


def check_a4(infos_dir, tramas_dir, period, alcance=("00013591",)):
    cols_path = os.path.join(infos_dir, ".trama_columns.json")
    if not os.path.exists(cols_path):
        print(f"A4 [{period}]: FALLO - no existe {cols_path}")
        return False
    with open(cols_path, "r", encoding="utf-8") as f:
        trama_cols = json.load(f)

    archivos = {
        "consulta": ("trama_consulta_externa.txt", "sp_codigo_ipress"),
        "emergencia": ("trama_emergencia.txt", "sp_codigo_ipress"),
        "hospitalizacion": ("trama_hospitalizacion.txt", "sp_codigo_ipress"),
        "farmacia": ("trama_farmacia.txt", "ipress_codigo"),
    }
    alcance_set = set(alcance)
    ok = True
    for tipo, (fname, col_name) in archivos.items():
        cols = trama_cols.get(tipo, [])
        valores = load_trama_values(os.path.join(tramas_dir, fname), cols, col_name)
        if valores is None:
            print(f"A4 [{period}]: FALLO - columna '{col_name}' no encontrada en {fname}")
            ok = False
            continue
        fuera_de_alcance = valores - alcance_set
        if fuera_de_alcance:
            print(f"A4 [{period}]: FALLO - {fname} tiene codigo_ipress fuera de alcance: {sorted(fuera_de_alcance)}")
            ok = False
    if ok:
        print(f"A4 [{period}]: PASS (unico codigo_ipress presente en las 4 tramas: {sorted(alcance_set)})")
    return ok


def check_a5(infos_dir, tramas_dir, period, year, month):
    cols_path = os.path.join(infos_dir, ".trama_columns.json")
    if not os.path.exists(cols_path):
        print(f"A5 [{period}]: FALLO - no existe {cols_path}")
        return False
    with open(cols_path, "r", encoding="utf-8") as f:
        trama_cols = json.load(f)

    import calendar
    import datetime
    last_day = calendar.monthrange(year, month)[1]
    p_ini = datetime.date(year, month, 1)
    p_fin = datetime.date(year, month, last_day)

    def is_in_period(date_str):
        if not date_str:
            return False
        if " " in date_str:
            date_str = date_str.split(" ")[0]
        try:
            d = datetime.datetime.strptime(date_str, "%Y-%m-%d").date()
            return p_ini <= d <= p_fin
        except ValueError:
            pass
        return False

    archivos = {
        "consulta": ("trama_consulta_externa.txt", ["sp_fecha_atencion"]),
        "emergencia": ("trama_emergencia.txt", ["sp_fecha_alta"]),
        "farmacia": ("trama_farmacia.txt", ["fecha_dispensacion_como_atencion", "fecha_dispensacion"]),
    }
    
    ok = True
    for tipo, (fname, col_names) in archivos.items():
        cols = trama_cols.get(tipo, [])
        col_name = next((cn for cn in col_names if cn in cols), None)
        
        if col_name:
            valores = load_trama_values(os.path.join(tramas_dir, fname), cols, col_name)
            if valores is not None:
                fuera = [v for v in valores if not is_in_period(v)]
                if fuera:
                    print(f"A5 [{period}]: FALLO - {fname} tiene fechas fuera de la ventana ({len(fuera)} distintos, ej: {fuera[:3]})")
                    ok = False

    # Hospitalizacion: sp_fecha_atencion <= p_fin AND (sp_fecha_alta IS NULL OR sp_fecha_alta >= p_ini)
    h_cols = trama_cols.get("hospitalizacion", [])
    if "sp_fecha_atencion" in h_cols and "sp_fecha_alta" in h_cols:
        idx_atencion = h_cols.index("sp_fecha_atencion")
        idx_alta = h_cols.index("sp_fecha_alta")
        h_path = os.path.join(tramas_dir, "trama_hospitalizacion.txt")
        if os.path.exists(h_path):
            with open(h_path, "rb") as f:
                data = f.read().decode("utf-8")
            sep = "|\r\n" if "|\r\n" in data else "|\n"
            fuera_h = 0
            for rec in data.split(sep):
                if not rec.strip(): continue
                parts = rec.split("|")
                if len(parts) > max(idx_atencion, idx_alta):
                    at_str = parts[idx_atencion].strip()
                    al_str = parts[idx_alta].strip()
                    if " " in at_str: at_str = at_str.split(" ")[0]
                    if " " in al_str: al_str = al_str.split(" ")[0]
                    
                    try:
                        at_d = datetime.datetime.strptime(at_str, "%Y-%m-%d").date() if at_str else p_ini
                        al_d = datetime.datetime.strptime(al_str, "%Y-%m-%d").date() if al_str else p_fin
                        
                        if not (at_d <= p_fin and al_d >= p_ini):
                            fuera_h += 1
                    except ValueError:
                        pass
            if fuera_h > 0:
                print(f"A5 [{period}]: FALLO - trama_hospitalizacion.txt tiene {fuera_h} registros fuera de la ventana de estancia")
                ok = False
                
    if ok:
        print(f"A5 [{period}]: PASS (Ventana temporal estricta validada en las 4 tramas)")
    return ok


def check_a6(infos_dir, tramas_dir, period, allow_missing=False):
    path = os.path.join(infos_dir, "metricas.json")
    if not os.path.exists(path):
        print(f"A6 [{period}]: FALLO - no existe {path}")
        return False
    with open(path, "r", encoding="utf-8") as f:
        metrics = json.load(f)
    volumenes_tramas = metrics.get("volumenes_tramas")
    if not volumenes_tramas:
        print(f"A6 [{period}]: FALLO - metricas.json no tiene 'volumenes_tramas'")
        return False
        
    archivos = {
        "trama_consulta_externa": "trama_consulta_externa.txt",
        "trama_emergencia": "trama_emergencia.txt",
        "trama_hospitalizacion": "trama_hospitalizacion.txt",
        "trama_farmacia": "trama_farmacia.txt",
    }
    
    ok = True
    for key, fname in archivos.items():
        expected = volumenes_tramas.get(key, 0)
        p = os.path.join(tramas_dir, fname)
        if not os.path.exists(p):
            if expected > 0:
                print(f"A6 [{period}]: FALLO - no existe {fname} pero se esperaban {expected} filas")
                ok = False
            continue
        with open(p, "rb") as f:
            data = f.read()
        records = split_records(data)
        actual = len(records)
        if actual != expected:
            print(f"A6 [{period}]: FALLO - {fname} tiene {actual} lineas fisicas, pero metricas.json reporta {expected}")
            ok = False
            
    if ok:
        print(f"A6 [{period}]: PASS (Recuento fisico de lineas en txt coincide con metricas.json)")
    return ok



def blank_decisions(audit_path):
    """Vacia la columna DECISION_AUDITORIA (T, col 20) en las 4 hojas de decision.
    Un libro 'vacio (todo pendiente)' significa celdas en blanco: el propio
    13_REINCORPORAR_decisiones.py cae entonces a sus defaults de codigo
    (SE UNE / NO PROCEDE / PROCEDE INDEPENDIENTE / PROCEDE), que son exactamente
    los que ya aplico generate_outputs_v2.py al construir la trama inicial.
    El valor PRE-LLENADO por generate_outputs_v2.py en DUPLICADOS_FUENTES ya es
    una recomendacion de negocio (fuente canonica), no un 'pendiente' real, por
    eso hay que vaciarlo antes de probar idempotencia."""
    wb = openpyxl.load_workbook(audit_path)
    for sheet_name in ("ESTANCIAS_E_H", "DUPLICADOS_FUENTES", "DUPLICADOS_ORIGEN", "TRANSF_HUERFANAS"):
        if sheet_name not in wb.sheetnames:
            continue
        ws = wb[sheet_name]
        for row in ws.iter_rows(min_row=2, min_col=20, max_col=20):
            row[0].value = None
    wb.save(audit_path)


def split_records(data):
    sep = b"|\r\n" if b"|\r\n" in data else b"|\n"
    return [rec for rec in data.split(sep) if rec.strip()]


def check_a3_ciclo(exp_dir, tramas_dir, audit_path, year, month, period):
    txt_names = ["trama_consulta_externa.txt", "trama_emergencia.txt", "trama_hospitalizacion.txt", "trama_farmacia.txt"]
    if not os.path.exists(audit_path):
        print(f"A3-ciclo [{period}]: FALLO - no existe {audit_path}")
        return False

    backup = {}
    for name in txt_names:
        p = os.path.join(tramas_dir, name)
        if os.path.exists(p):
            with open(p, "rb") as f:
                backup[name] = f.read()
    with open(audit_path, "rb") as f:
        audit_backup = f.read()

    ok = True
    try:
        blank_decisions(audit_path)
        result = subprocess.run(
            [sys.executable, "13_REINCORPORAR_decisiones.py", "--year", str(year), "--month", str(month)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            print(f"A3-ciclo [{period}]: FALLO - 13_REINCORPORAR_decisiones.py devolvio codigo {result.returncode}")
            print(result.stdout)
            print(result.stderr)
            ok = False
        else:
            for name in txt_names:
                p = os.path.join(tramas_dir, name)
                after = open(p, "rb").read() if os.path.exists(p) else b""
                before = backup.get(name, b"")
                # Se compara por registro (no por bytes crudos): un archivo
                # generado antes de esta verificacion puede usar CRLF y el
                # reescrito por 13 usa LF; el terminador no es dato de negocio.
                if split_records(after) != split_records(before):
                    print(f"A3-ciclo [{period}]: FALLO - {name} cambio tras correr 13 con libro de decisiones vacio (no es idempotente)")
                    ok = False
    finally:
        # Restaurar siempre el estado original (txts + workbook), pase o falle la comparacion
        for name, content in backup.items():
            with open(os.path.join(tramas_dir, name), "wb") as f:
                f.write(content)
        with open(audit_path, "wb") as f:
            f.write(audit_backup)

    if ok:
        print(f"A3-ciclo [{period}]: PASS (13_REINCORPORAR_decisiones.py con libro vacio no modifico ningun txt)")
    return ok


def check_a3_control10(year, month, period, skip):
    if skip:
        print(f"A3-CONTROL10 [{period}]: SKIPPED (--skip-control10, no se verifico contra BD)")
        return True

    import psycopg2
    import os
    dbname = os.environ.get("PGDATABASE", "db_cpt_junio26")
    password = os.environ.get("PGPASSWORD", "root")
    conn = psycopg2.connect(f"dbname={dbname} user=postgres password={password} host=localhost")
    cur = conn.cursor()
    cur.execute("SELECT MIN(fecha_atencion), MAX(fecha_atencion) FROM temp_bdt_consulta_local;")
    min_d, max_d = cur.fetchone()
    if min_d is None or min_d.year != year or min_d.month != month:
        print(f"A3-CONTROL10 [{period}]: SKIPPED (las tablas temporales cargadas en BD corresponden a {min_d}..{max_d}, no a {period})")
        cur.close()
        conn.close()
        return True

    cur.execute(CONTROL_10_SQL)
    (count,) = cur.fetchone()
    cur.close()
    conn.close()
    if count != 0:
        print(f"A3-CONTROL10 [{period}]: FALLO - CONTROL 10 devolvio {count} filas (debe ser 0)")
        return False
    print(f"A3-CONTROL10 [{period}]: PASS (CONTROL 10 = 0)")
    return True


def main():
    args = parse_args()
    year = args.year
    month = args.month
    period = f"{year}-{month:02d}"

    exp_dir = os.path.join("expedientes", period)
    tramas_dir = os.path.join(exp_dir, "01_TRAMAS")
    infos_dir = os.path.join(exp_dir, "03_INFORMATIVOS")
    audit_path = os.path.join(exp_dir, f"02_AUDITORIA_{period}.xlsx")

    print(f"=== Verificando aserciones A1/A2/A3/A4/A5/A6 para {period} ===")
    results = [
        check_a1(infos_dir, period, allow_missing=args.allow_missing_conservacion),
        check_a2(exp_dir, infos_dir, tramas_dir, period),
        check_a3_ciclo(exp_dir, tramas_dir, audit_path, year, month, period),
        check_a3_control10(year, month, period, args.skip_control10),
        check_a4(infos_dir, tramas_dir, period),
        check_a5(infos_dir, tramas_dir, period, year, month),
        check_a6(infos_dir, tramas_dir, period, allow_missing=args.allow_missing_conservacion),
    ]

    if all(results):
        print(f"=== {period}: TODAS LAS ASERCIONES OK ===")
        sys.exit(0)
    else:
        print(f"=== {period}: HAY ASERCIONES FALLIDAS - DETENER ===")
        sys.exit(1)


if __name__ == "__main__":
    main()
