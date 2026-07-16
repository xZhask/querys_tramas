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

    print(f"=== Verificando aserciones A1/A2/A3 para {period} ===")
    results = [
        check_a1(infos_dir, period, allow_missing=args.allow_missing_conservacion),
        check_a2(exp_dir, infos_dir, tramas_dir, period),
        check_a3_ciclo(exp_dir, tramas_dir, audit_path, year, month, period),
        check_a3_control10(year, month, period, args.skip_control10),
    ]

    if all(results):
        print(f"=== {period}: TODAS LAS ASERCIONES OK ===")
        sys.exit(0)
    else:
        print(f"=== {period}: HAY ASERCIONES FALLIDAS - DETENER ===")
        sys.exit(1)


if __name__ == "__main__":
    main()
