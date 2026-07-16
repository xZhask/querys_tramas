import os
import sys
import json
import argparse
import datetime
import psycopg2
import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill, Border, Side
from openpyxl.worksheet.datavalidation import DataValidation

def parse_args():
    parser = argparse.ArgumentParser(description="Generate Rediseño de Salidas v2 outputs")
    parser.add_argument("--year", type=int, default=2025, help="Year of the period")
    parser.add_argument("--month", type=int, required=True, help="Month of the period (e.g. 7)")
    return parser.parse_args()

def connect_db():
    import os
    dbname = os.environ.get("PGDATABASE", "db_cpt_junio26")
    password = os.environ.get("PGPASSWORD", "root")
    return psycopg2.connect(f"dbname={dbname} user=postgres password={password} host=localhost")

def parse_date(val):
    if val is None:
        return None
    if isinstance(val, datetime.date) or isinstance(val, datetime.datetime):
        return datetime.datetime(val.year, val.month, val.day)
    if isinstance(val, str):
        val = val.strip()
        if not val:
            return None
        for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d', '%d/%m/%Y %H:%M:%S', '%d/%m/%Y'):
            try:
                dt = datetime.datetime.strptime(val, fmt)
                return datetime.datetime(dt.year, dt.month, dt.day)
            except ValueError:
                pass
    return None

def execute_sql_file(cur, filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    sql_lines = []
    for line in lines:
        l = line.strip()
        if l.startswith('--'):
            continue
        sql_lines.append(line)
    sql_content = "".join(sql_lines).strip()
    if not sql_content:
        return []
    cur.execute(sql_content)
    cols = [col[0] for col in cur.description]
    rows = cur.fetchall()
    return [dict(zip(cols, row)) for row in rows]

def format_trama_val(val):
    if val is None:
        return ""
    if isinstance(val, datetime.datetime):
        return val.strftime('%Y-%m-%d %H:%M:%S')
    if isinstance(val, datetime.date):
        # Check if it was originally formatted as DD/MM/YYYY
        # Actually, in the CPT database CPT dates are YYYY-MM-DD, SIGESAPOL is YYYY-MM-DD.
        # Let's keep YYYY-MM-DD for standard dates, but let's check if we should check the birth date format.
        # We will format dates as YYYY-MM-DD except if it looks like a birthday and we want to be safe.
        # Let's just output YYYY-MM-DD as standard, or DD/MM/YYYY if birth date.
        # Wait, the birth date in the old trama was DD/MM/YYYY. Let's write a simple logic:
        # If it's a date and represents sp_fecha_nacimiento, we format it as %d/%m/%Y.
        return val.strftime('%Y-%m-%d')
    return str(val)

def write_trama_file(filepath, rows, col_keys):
    # newline='' disables universal-newline translation: some field values
    # (diagnostic descriptions, etc.) carry stray embedded \r/\n characters,
    # and text-mode translation would otherwise mangle those on every write.
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        for r in rows:
            line_parts = []
            for col in col_keys:
                val = r.get(col)
                # Specific format for birth dates:
                if col == 'sp_fecha_nacimiento' and isinstance(val, (datetime.date, datetime.datetime)):
                    line_parts.append(val.strftime('%d/%m/%Y'))
                else:
                    line_parts.append(format_trama_val(val))
            # Write line with trailing pipe
            f.write("|".join(line_parts) + "|\n")

def add_validation(ws, formula, cell_range):
    dv = DataValidation(type="list", formula1=formula, allow_blank=True)
    dv.error ='Valor no válido'
    dv.errorTitle = 'Selección inválida'
    dv.prompt = 'Por favor seleccione una opción de la lista'
    dv.promptTitle = 'Opciones válidas'
    ws.add_data_validation(dv)
    dv.add(cell_range)

def main():
    args = parse_args()
    year = args.year
    month = args.month
    month_str = f"{month:02d}"
    period = f"{year}-{month_str}"
    
    print(f"Executing Rediseño de Salidas v2 for period {period}...")
    
    conn = connect_db()
    cur = conn.cursor()
    
    # 1. Load CPT Hospitalization original dates for rollback
    cur.execute("SELECT id_prestacion_cpt, fecha_atencion, fecha_alta FROM temp_bdt_hospitalizacion_local;")
    orig_dates_cpt = {str(r[0]): (parse_date(r[1]), parse_date(r[2])) for r in cur.fetchall() if r[0] is not None}
    
    # Load raw stays and procedures from SQL armado scripts
    # We load them before any file outputs
    print("Loading raw data from SQL files...")
    consulta_raw = execute_sql_file(cur, "09_ARMADO_consulta_externa.sql")
    emergencia_raw = execute_sql_file(cur, "10_ARMADO_emergencia.sql")
    hospitalizacion_raw = execute_sql_file(cur, "11_ARMADO_hospitalizacion.sql")
    
    # Assign a unique row index to each record to prevent accidental multi-row exclusions
    for idx, r in enumerate(consulta_raw): r['_row_idx'] = f"C_{idx}"
    for idx, r in enumerate(emergencia_raw): r['_row_idx'] = f"E_{idx}"
    for idx, r in enumerate(hospitalizacion_raw): r['_row_idx'] = f"H_{idx}"

    # Farmacia query must run on sigesapol_junio database
    import os
    password_sig = os.environ.get("PGPASSWORD", "root")
    conn_sig = psycopg2.connect(f"dbname=sigesapol_junio user=postgres password={password_sig} host=localhost")
    cur_sig = conn_sig.cursor()
    farmacia_raw = execute_sql_file(cur_sig, "12_SIGESAPOL_farmacia.sql")
    cur_sig.close()
    conn_sig.close()
    
    print(f"Loaded: {len(consulta_raw)} Consultation, {len(emergencia_raw)} Emergency, {len(hospitalizacion_raw)} Hospitalization, {len(farmacia_raw)} Farmacia records.")
    
    # Load E->H pairs (Caso A)
    # We match using patient DNI and date overlap
    cur.execute("""
        SELECT 
            e.id_emergencia_sigesapol,
            e.sp_numero_documento_paciente,
            e.sp_fecha_atencion AS e_ing,
            e.sp_fecha_alta_emergencia AS e_alt,
            h.id_prestacion_cpt,
            h.sp_fecha_atencion AS h_ing,
            h.sp_fecha_alta AS h_alt,
            e.sp_apellido_paterno_paciente,
            e.sp_apellido_materno_paciente,
            e.sp_nombres_paciente,
            e.prioridad,
            e.sp_codigo_dx_01,
            e.sp_descripcion_dx_01,
            e.sp_codigo_dx_02,
            e.sp_descripcion_dx_02,
            e.sp_codigo_dx_03,
            e.sp_descripcion_dx_03
        FROM temp_emergencia_sigesapol_estancia e
        JOIN temp_hospitalizacion_local h 
          ON h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
         AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
         AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
         AND NOT (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15);
    """)
    pairs_rows = cur.fetchall()
    
    # Track Caso A pairs
    paired_emergencies = {} # id_emergencia_sigesapol -> CPT stay info
    paired_hospitalizations = {} # id_prestacion_cpt -> Emergency stay info
    
    eh_groups = []
    group_counter = 1
    
    for row in pairs_rows:
        e_id, dni, e_ing, e_alt, h_id, h_ing, h_alt, pat_pat, pat_mat, pat_nom, prio, dx1, dx1_d, dx2, dx2_d, dx3, dx3_d = row
        group_id = f"GRP_{group_counter:03d}"
        group_counter += 1
        
        e_ing_dt = parse_date(e_ing)
        e_alt_dt = parse_date(e_alt)
        h_ing_dt = parse_date(h_ing)
        h_alt_dt = parse_date(h_alt)
        
        pair_info = {
            'group_id': group_id,
            'dni': dni,
            'e_id': e_id,
            'h_id': str(h_id),
            'e_ing': e_ing_dt,
            'e_alt': e_alt_dt,
            'h_ing_orig': orig_dates_cpt.get(str(h_id), (h_ing_dt, h_alt_dt))[0],
            'h_alt_orig': orig_dates_cpt.get(str(h_id), (h_ing_dt, h_alt_dt))[1],
            'h_ing_extended': e_ing_dt if h_ing_dt is None else min(e_ing_dt, h_ing_dt),
            'h_alt_extended': e_alt_dt if h_alt_dt is None else max(e_alt_dt, h_alt_dt),
            'prioridad': prio,
            'nombres_paciente': f"{pat_pat} {pat_mat}, {pat_nom}",
            'dx_01_codigo': dx1,
            'dx_01_descripcion': dx1_d,
            'dx_02_codigo': dx2,
            'dx_02_descripcion': dx2_d,
            'dx_03_codigo': dx3,
            'dx_03_descripcion': dx3_d
        }
        eh_groups.append(pair_info)
        paired_emergencies[e_id] = pair_info
        paired_hospitalizations[str(h_id)] = pair_info

    print(f"Found {len(eh_groups)} E->H stays solapamientos (Caso A).")

    # Group procedures and laboratories by (documento, fecha, codigo) to find duplicates
    # We unblock all procedures and labs from CE, EME and HOSP
    # Precedence: E->H package > Duplicados Fuentes > Duplicados Origen
    
    # 1. E->H package classification:
    # Any procedure/lab belonging to a paired emergency stay (same patient DNI, date within emergency stay dates)
    # is RETENIDA and marked as eh_package.
    retained_package_rows = []
    
    eh_groups_by_dni = {}
    for g in eh_groups:
        eh_groups_by_dni.setdefault(g['dni'], []).append(g)
        
    def is_in_eh_package(dni, date):
        if not dni or not date:
            return False
        for g in eh_groups_by_dni.get(dni, []):
            if g['e_ing'] <= date <= g['e_alt']:
                return g
        return None

    # Filter out E->H packages
    clean_consulta = []
    clean_emergencia = []
    clean_hospitalizacion = []
    
    # Keep track of excluded packages
    excluded_package_consulta = []
    excluded_package_emergencia = []
    excluded_package_hospitalizacion = []
    
    # Process Consultation
    for row in consulta_raw:
        # Consulta has no E->H package (it's CE, not EME/HOSP)
        clean_consulta.append(row)
        
    # Process Emergency
    for row in emergencia_raw:
        base_type = row.get('base')
        if base_type == 'estancia en emergency': # wait, spelling in sql: 'estancia en emergencia'
            # Check if this is the stay itself
            e_id = row.get('id_atencion_emergencia')
            if e_id in paired_emergencies:
                # Retained stay!
                continue
        
        # Check if it's a procedure/lab in emergency package
        dni = row.get('sp_numero_documento_paciente')
        date_at = parse_date(row.get('sp_fecha_atencion'))
        g = is_in_eh_package(dni, date_at)
        if g:
            # Belongs to emergency package! Retained!
            row['eh_group_id'] = g['group_id']
            excluded_package_emergencia.append(row)
        else:
            clean_emergencia.append(row)
            
    # Process Hospitalization
    for row in hospitalizacion_raw:
        base_type = row.get('base')
        if base_type == 'estancia hospitalaria':
            h_id = str(row.get('id_prestacion_cpt'))
            if h_id in paired_hospitalizations:
                # Paired hospitalization: we must write it to the initial tramas using its EXTENDED dates by default (SE UNE)!
                g = paired_hospitalizations[h_id]
                row_copy = dict(row)
                row_copy['sp_fecha_atencion'] = g['h_ing_extended']
                row_copy['sp_fecha_alta'] = g['h_alt_extended']
                if g['h_alt_extended'] and g['h_ing_extended']:
                    ext_days = (g['h_alt_extended'] - g['h_ing_extended']).days + 1
                else:
                    ext_days = int(row.get('sp_suma_cantidad') or 1)
                row_copy['sp_suma_cantidad'] = ext_days
                # Recalculate valuation
                rate = float(row.get('sp_valorizacion_total') or 0) / float(row.get('sp_suma_cantidad') or 1)
                row_copy['sp_valorizacion_total'] = round(ext_days * rate, 2)
                clean_hospitalizacion.append(row_copy)
                continue
        
        # Check if it's hospitalisation procedure/lab
        # Does it belong to emergency package?
        dni = row.get('sp_numero_documento_paciente')
        date_at = parse_date(row.get('sp_fecha_atencion'))
        g = is_in_eh_package(dni, date_at)
        if g and row.get('digitador_prestacion') == 'SIGESAPOL':
            # This is a procedure/lab from emergency that was copied to hospitalisation table,
            # or is part of the emergency package! Retained!
            row['eh_group_id'] = g['group_id']
            excluded_package_hospitalizacion.append(row)
        else:
            clean_hospitalizacion.append(row)

    print(f"Retained emergency stays and packages: {len(eh_groups)} stays, {len(excluded_package_emergencia) + len(excluded_package_hospitalizacion)} package records.")

    # 2. Duplicate between sources (DUPLICADOS_FUENTES) & Duplicados de Origen (DUPLICADOS_ORIGEN)
    # We group all procedures and labs from clean lists by the composite key of
    # their tipo (CONTEXTO_CANONICO.md regla #2 / checks 24-25 del piloto):
    #   Tipo 1 (consulta externa):        paciente + fecha + código + MEDICO
    #   Tipo 2 y 3 (emergencia/hosp.):     paciente + fecha + código + CANTIDAD
    # Grouping by paciente+fecha+código alone (sin el discriminador de tipo)
    # sobre-cuenta: dos atenciones legítimas del mismo código el mismo día con
    # médico o cantidad distintos NO son duplicados y deben quedar en grupos
    # separados.
    grouped_procs = {}

    # We combine procedures and labs from clean lists for duplicate checking
    # Note: we only check procedures/laboratories (base in ['procedimientos en consulta externa', 'laboratorio en consulta externa', 'procedimientos en emergencia', 'laboratorio en emergencia', 'procedimientos en hospitalización', 'laboratorio en hospitalización'])
    # Stays are NOT checked here.
    def add_to_group(row, source_type):
        base = row.get('base', '')
        if 'estancia' in base:
            return
        dni = row.get('sp_numero_documento_paciente')
        date_at = parse_date(row.get('sp_fecha_atencion'))
        code = row.get('sp_codigo_procedimiento')
        if not dni or not date_at or not code:
            return

        # Normalize date to string for key
        date_str = date_at.strftime('%Y-%m-%d')
        if 'consulta' in base:
            discriminador = row.get('sp_numero_documento_responsable')  # Tipo 1: +medico
        else:
            discriminador = row.get('sp_suma_cantidad')                 # Tipo 2/3: +cantidad
        key = (dni, date_str, code, discriminador)
        grouped_procs.setdefault(key, []).append((row, source_type))

    for r in clean_consulta: add_to_group(r, 'consulta')
    for r in clean_emergencia: add_to_group(r, 'emergencia')
    for r in clean_hospitalizacion: add_to_group(r, 'hospitalizacion')
    
    # Now classify groups
    retained_duplicates_sources = [] # list of dicts (CPT & SIGESAPOL rows)
    duplicates_origin_list = []      # list of dicts (same source rows)
    
    # Maps to track which records are excluded from clean tramas because they are retained duplicates
    excluded_duplicate_ids = set() # (source_type, id_prestacion_cpt/lab)
    
    dup_fuentes_counter = 1
    dup_origen_counter = 1
    
    for key, items in grouped_procs.items():
        # Check if duplicate between CPT and SIGESAPOL
        cpt_items = [it for it in items if it[0].get('digitador_prestacion') != 'SIGESAPOL']
        sig_items = [it for it in items if it[0].get('digitador_prestacion') == 'SIGESAPOL']
        
        if cpt_items and sig_items:
            # Duplicate between sources! RETENIDA!
            group_id = f"DUP_F_{dup_fuentes_counter:04d}"
            dup_fuentes_counter += 1
            
            # Exclude both from the initial tramas
            for row, source_type in items:
                # Mark as excluded by unique row index
                excluded_duplicate_ids.add((source_type, row['_row_idx']))
                
                # Copy row with group info for Excel
                row_copy = dict(row)
                row_copy['dup_group_id'] = group_id
                retained_duplicates_sources.append((row_copy, source_type))
                
        elif len(items) > 1:
            # Duplicate of origin! INFORMATIVA (they DO enter the tramas)
            group_id = f"DUP_O_{dup_origen_counter:04d}"
            dup_origen_counter += 1
            
            for row, source_type in items:
                row_copy = dict(row)
                row_copy['dup_group_id'] = group_id
                duplicates_origin_list.append((row_copy, source_type))

    print(f"Classified: {len(retained_duplicates_sources)//2} source duplicate pairs, {len(duplicates_origin_list)} origin duplicate records.")

    # 3. Transiciones Huérfanas (TRANSF_HUERFANAS)
    # We query the database for emergencies with condicion_alta = 3 and no hospitalization (CONTROL 12)
    # They are INFORMATIVA.
    cur.execute("""
        SELECT 
            e.id_emergencia_sigesapol,
            e.sp_numero_documento_paciente,
            e.sp_fecha_atencion,
            e.sp_fecha_alta_emergencia,
            e.sp_apellido_paterno_paciente,
            e.sp_apellido_materno_paciente,
            e.sp_nombres_paciente,
            e.prioridad,
            e.sp_codigo_dx_01,
            e.sp_descripcion_dx_01,
            e.sp_codigo_dx_02,
            e.sp_descripcion_dx_02,
            e.sp_codigo_dx_03,
            e.sp_descripcion_dx_03
        FROM temp_emergencia_sigesapol_estancia e
        WHERE e.condicion_alta = 3
          AND NOT EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
              AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
          );
    """)
    huerfanas_rows = cur.fetchall()
    
    huerfanas_list = []
    for r in huerfanas_rows:
        # Build dictionary matching standard columns
        e_id, dni, e_ing, e_alt, pat_pat, pat_mat, pat_nom, prio, dx1, dx1_d, dx2, dx2_d, dx3, dx3_d = r
        prio_code = '99281'
        if prio == 1: prio_code = '99285'
        elif prio == 2: prio_code = '99284'
        elif prio == 3: prio_code = '99282'
        elif prio == 4: prio_code = '99281'
        
        huerfanas_list.append({
            'periodo': period,
            'tipo_atencion': '2',
            'documento_paciente': dni,
            'nombres_paciente': f"{pat_pat} {pat_mat}, {pat_nom}",
            'fecha_ingreso': parse_date(e_ing),
            'fecha_alta': parse_date(e_alt),
            'dx_01_tipo': '2',
            'dx_01_codigo': dx1,
            'dx_01_descripcion': dx1_d,
            'dx_02_tipo': '2' if dx2 else None,
            'dx_02_codigo': dx2,
            'dx_02_descripcion': dx2_d,
            'dx_03_tipo': '2' if dx3 else None,
            'dx_03_codigo': dx3,
            'dx_03_descripcion': dx3_d,
            'codigo_procedimiento': prio_code,
            'descripcion_procedimiento': f"Consulta en emergencia prioridad {prio}",
            'fuentes': 'SIGESAPOL',
            'MOTIVO': 'TRANSFERENCIA SIN HOSPITALIZACION',
            'DECISION_AUDITORIA': None,
            'OBSERVACION_AUDITORIA': None,
            'e_id': e_id
        })

    print(f"Found {len(huerfanas_list)} transferencias huérfanas (INFORMATIVA).")

    # 4. Filter clean lists by removing retained duplicates
    final_consulta = [r for r in clean_consulta if not (( 'consulta', r['_row_idx'] ) in excluded_duplicate_ids)]
    final_emergencia = [r for r in clean_emergencia if not (( 'emergencia', r['_row_idx'] ) in excluded_duplicate_ids)]
    final_hospitalizacion = [r for r in clean_hospitalizacion if not (( 'hospitalizacion', r['_row_idx'] ) in excluded_duplicate_ids)]
    final_farmacia = list(farmacia_raw) # Farmacia is always clean
    
    # Append emergency package rows directly to final_hospitalizacion (SE UNE default)
    for r in excluded_package_emergencia:
        r_copy = dict(r)
        final_hospitalizacion.append(r_copy)
    for r in excluded_package_hospitalizacion:
        r_copy = dict(r)
        final_hospitalizacion.append(r_copy)

    print(f"Final clean lines to write: CE={len(final_consulta)}, EME={len(final_emergencia)}, HOSP={len(final_hospitalizacion)}, FARM={len(final_farmacia)}")

    # A2 (PAQUETE COMPLETO): ningun procedimiento/laboratorio de una estancia RETENIDA
    # (paquete Caso A movido a hospitalizacion) debe quedar huerfano en trama_emergencia.
    def row_key(r):
        return (r.get('sp_numero_documento_paciente'), parse_date(r.get('sp_fecha_atencion')), r.get('sp_codigo_procedimiento'))
    retained_package_keys = {row_key(r) for r in excluded_package_emergencia} | {row_key(r) for r in excluded_package_hospitalizacion}
    leaked_in_emergencia = [r for r in final_emergencia if row_key(r) in retained_package_keys]
    if leaked_in_emergencia:
        print(f"A2 FALLIDA: {len(leaked_in_emergencia)} procedimientos/laboratorio de estancias RETENIDAS (Caso A) quedaron en trama_emergencia en vez de moverse a trama_hospitalizacion.")
        sys.exit(1)
    print("A2 (paquete completo): OK, cero fugas de paquete retenido en trama_emergencia.")

    # A1 (CONSERVACION): LIMPIA + RETENIDA + INFORMATIVA = total extraido, por tipo de trama.
    retenida_por_tipo = {'consulta': 0, 'emergencia': 0, 'hospitalizacion': 0}
    for _, stype in retained_duplicates_sources:
        retenida_por_tipo[stype] = retenida_por_tipo.get(stype, 0) + 1
    informativa_por_tipo = {'consulta': 0, 'emergencia': 0, 'hospitalizacion': 0}
    for _, stype in duplicates_origin_list:
        informativa_por_tipo[stype] = informativa_por_tipo.get(stype, 0) + 1
    informativa_por_tipo['emergencia'] += len(huerfanas_list)

    total_extraido = {
        'consulta': len(consulta_raw),
        'emergencia': len(emergencia_raw) - len(excluded_package_emergencia),
        'hospitalizacion': len(hospitalizacion_raw) + len(excluded_package_emergencia),
        'farmacia': len(farmacia_raw)
    }
    final_counts = {
        'consulta': len(final_consulta),
        'emergencia': len(final_emergencia),
        'hospitalizacion': len(final_hospitalizacion),
        'farmacia': len(final_farmacia)
    }

    conservacion = {}
    conservacion_failed = []
    for tipo in ('consulta', 'emergencia', 'hospitalizacion', 'farmacia'):
        retenida = retenida_por_tipo.get(tipo, 0)
        informativa = informativa_por_tipo.get(tipo, 0)
        limpia = final_counts[tipo] - informativa
        total = total_extraido[tipo]
        residuo = total - (limpia + retenida + informativa)
        conservacion[tipo] = {
            'limpia': limpia,
            'retenida': retenida,
            'informativa': informativa,
            'total_extraido': total,
            'residuo': residuo
        }
        if residuo != 0:
            conservacion_failed.append(tipo)

    if conservacion_failed:
        print(f"A1 FALLIDA: residuo distinto de cero en tramas: {conservacion_failed}")
        print(json.dumps(conservacion, indent=2))
        sys.exit(1)
    print("A1 (conservacion): OK, residuo = 0 en las 4 tramas.")

    # 5. Export clean tramas to 01_TRAMAS/
    exp_dir = os.path.join("expedientes", period)
    tramas_dir = os.path.join(exp_dir, "01_TRAMAS")
    infos_dir = os.path.join(exp_dir, "03_INFORMATIVOS")
    os.makedirs(tramas_dir, exist_ok=True)
    os.makedirs(infos_dir, exist_ok=True)
    
    # We get column keys from headers in SQL files
    cur.execute("SELECT * FROM temp_bdt_consulta_local LIMIT 0;")
    # Wait! The columns list must match the select statement in 09_ARMADO_consulta_externa.sql
    # We can just extract them from our execute_sql_file description or keys!
    # Let's see, what are the keys of rows?
    # In Python, dict keys preserve the order of the columns in select statement in newer Python versions!
    # So we can just use the keys of the first row!
    cols_consulta = [k for k in list(consulta_raw[0].keys()) if k not in ('_row_idx', 'dup_group_id', 'eh_group_id')] if consulta_raw else []
    cols_emergencia = [k for k in list(emergencia_raw[0].keys()) if k not in ('_row_idx', 'dup_group_id', 'eh_group_id')] if emergencia_raw else []
    cols_hospitalizacion = [k for k in list(hospitalizacion_raw[0].keys()) if k not in ('_row_idx', 'dup_group_id', 'eh_group_id')] if hospitalizacion_raw else []
    cols_farmacia = [k for k in list(farmacia_raw[0].keys()) if k not in ('_row_idx', 'dup_group_id', 'eh_group_id')] if farmacia_raw else []
    
    with open(os.path.join(infos_dir, ".trama_columns.json"), 'w', encoding='utf-8') as f:
        json.dump({
            'consulta': cols_consulta,
            'emergencia': cols_emergencia,
            'hospitalizacion': cols_hospitalizacion,
            'farmacia': cols_farmacia
        }, f, default=str)
        
    write_trama_file(os.path.join(tramas_dir, "trama_consulta_externa.txt"), final_consulta, cols_consulta)
    write_trama_file(os.path.join(tramas_dir, "trama_emergencia.txt"), final_emergencia, cols_emergencia)
    write_trama_file(os.path.join(tramas_dir, "trama_hospitalizacion.txt"), final_hospitalizacion, cols_hospitalizacion)
    write_trama_file(os.path.join(tramas_dir, "trama_farmacia.txt"), final_farmacia, cols_farmacia)
    
    print("Clean tramas successfully written.")

    # 6. Save private retained package and duplicate JSON files in 03_INFORMATIVOS/
    # This allows script 13 to easily read and restore them!
    with open(os.path.join(infos_dir, ".retained_package_emergencia.json"), 'w', encoding='utf-8') as f:
        json.dump(excluded_package_emergencia, f, default=str)
    with open(os.path.join(infos_dir, ".retained_package_hospitalizacion.json"), 'w', encoding='utf-8') as f:
        json.dump(excluded_package_hospitalizacion, f, default=str)
    with open(os.path.join(infos_dir, ".retained_duplicates.json"), 'w', encoding='utf-8') as f:
        json.dump(retained_duplicates_sources, f, default=str)
    with open(os.path.join(infos_dir, ".eh_groups.json"), 'w', encoding='utf-8') as f:
        # We save stays info
        # Let's save the original stay rows for Emergency and CPT hospitalization too!
        # First find emergency stay rows:
        retained_emer_stays = []
        for r in emergencia_raw:
            if r.get('base') == 'estancia en emergencia':
                if r.get('id_atencion_emergencia') in paired_emergencies:
                    retained_emer_stays.append(r)
                    
        # Find original CPT stay rows:
        retained_cpt_stays = []
        for r in hospitalizacion_raw:
            if r.get('base') == 'estancia hospitalaria':
                h_id = str(r.get('id_prestacion_cpt'))
                if h_id in paired_hospitalizations:
                    retained_cpt_stays.append(r)
                    
        json.dump({
            'groups': eh_groups,
            'retained_emer_stays': retained_emer_stays,
            'retained_cpt_stays': retained_cpt_stays
        }, f, default=str)
        
    print("Private logs for reincorporation successfully written.")

    # 7. Generate Excel 02_AUDITORIA_<AAAA-MM>.xlsx
    audit_path = os.path.join(exp_dir, f"02_AUDITORIA_{period}.xlsx")
    wb = openpyxl.Workbook()
    
    headers = [
        'periodo', 'tipo_atencion', 'documento_paciente', 'nombres_paciente',
        'fecha_ingreso', 'fecha_alta', 'dx_01_tipo', 'dx_01_codigo', 'dx_01_descripcion',
        'dx_02_tipo', 'dx_02_codigo', 'dx_02_descripcion', 'dx_03_tipo', 'dx_03_codigo', 'dx_03_descripcion',
        'codigo_procedimiento', 'descripcion_procedimiento', 'fuentes', 'MOTIVO', 'DECISION_AUDITORIA', 'OBSERVACION_AUDITORIA'
    ]
    
    # Helper to write sheet
    def create_audit_sheet(ws, title, rows_data, decision_formula=None):
        ws.title = title
        ws.append(headers)
        
        # Styles
        font_header = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
        fill_header = PatternFill(start_color="333333", end_color="333333", fill_type="solid")
        align_center = Alignment(horizontal="center", vertical="center")
        align_left = Alignment(horizontal="left", vertical="center")
        border_thin = Border(
            left=Side(style='thin', color='DDDDDD'),
            right=Side(style='thin', color='DDDDDD'),
            top=Side(style='thin', color='DDDDDD'),
            bottom=Side(style='thin', color='DDDDDD')
        )
        font_cell = Font(name="Calibri", size=10)
        
        for col_idx, h in enumerate(headers, 1):
            cell = ws.cell(row=1, column=col_idx)
            cell.font = font_header
            cell.fill = fill_header
            cell.alignment = align_center
            
        date_format = 'yyyy-mm-dd'
        col_widths = [0] * len(headers)
        
        for r_idx, r in enumerate(rows_data, 2):
            for c_idx, h in enumerate(headers, 1):
                val = r.get(h)
                cell = ws.cell(row=r_idx, column=c_idx, value=val)
                cell.font = font_cell
                cell.border = border_thin
                
                # Alignments and Formats
                if h in ['fecha_ingreso', 'fecha_alta']:
                    if isinstance(val, (datetime.datetime, datetime.date)):
                        cell.number_format = date_format
                    cell.alignment = align_center
                elif h in ['periodo', 'tipo_atencion', 'documento_paciente', 'dx_01_codigo', 'dx_02_codigo', 'dx_03_codigo', 'codigo_procedimiento', 'fuentes']:
                    cell.alignment = align_center
                else:
                    cell.alignment = align_left
                    
                val_str = str(val or '')
                if len(val_str) > col_widths[c_idx-1]:
                    col_widths[c_idx-1] = len(val_str)
                    
        # Apply dropdown list validation on column T (20) once for the whole column
        if decision_formula and rows_data:
            max_row = len(rows_data) + 1
            dv = DataValidation(type="list", formula1=decision_formula, allow_blank=True)
            dv.error ='Valor no válido'
            dv.errorTitle = 'Selección inválida'
            dv.prompt = 'Por favor seleccione una opción de la lista'
            dv.promptTitle = 'Opciones válidas'
            ws.add_data_validation(dv)
            dv.add(f"T2:T{max_row}")
            
        # Auto adjust column widths
        for c_idx, width in enumerate(col_widths, 1):
            col_letter = openpyxl.utils.get_column_letter(c_idx)
            ws.column_dimensions[col_letter].width = max(width + 3, 10)
            
    # Sheet 1: ESTANCIAS_E_H
    # Convert E->H pairs to sheet rows
    eh_sheet_rows = []
    for g in eh_groups:
        # Emergency stay row
        eh_sheet_rows.append({
            'periodo': period,
            'tipo_atencion': '2',
            'documento_paciente': g['dni'],
            'nombres_paciente': g['nombres_paciente'],
            'fecha_ingreso': g['e_ing'],
            'fecha_alta': g['e_alt'],
            'dx_01_tipo': '2',
            'dx_01_codigo': g['dx_01_codigo'],
            'dx_01_descripcion': g['dx_01_descripcion'],
            'dx_02_tipo': '2' if g['dx_02_codigo'] else None,
            'dx_02_codigo': g['dx_02_codigo'],
            'dx_02_descripcion': g['dx_02_descripcion'],
            'dx_03_tipo': '2' if g['dx_03_codigo'] else None,
            'dx_03_codigo': g['dx_03_codigo'],
            'dx_03_descripcion': g['dx_03_descripcion'],
            'codigo_procedimiento': '99281', # Mapped CPMS code of stay
            'descripcion_procedimiento': 'Consulta de emergencia',
            'fuentes': 'SIGESAPOL',
            'MOTIVO': f"SOLAPAMIENTO E-H Group {g['group_id']}",
            'DECISION_AUDITORIA': 'SE UNE', # Default decision
            'OBSERVACION_AUDITORIA': ''
        })
        # CPT hospitalisation stay row
        eh_sheet_rows.append({
            'periodo': period,
            'tipo_atencion': '3',
            'documento_paciente': g['dni'],
            'nombres_paciente': g['nombres_paciente'],
            'fecha_ingreso': g['h_ing_orig'],
            'fecha_alta': g['h_alt_orig'],
            'dx_01_tipo': '2',
            'dx_01_codigo': g['dx_01_codigo'],
            'dx_01_descripcion': g['dx_01_descripcion'],
            'dx_02_tipo': '2' if g['dx_02_codigo'] else None,
            'dx_02_codigo': g['dx_02_codigo'],
            'dx_02_descripcion': g['dx_02_descripcion'],
            'dx_03_tipo': '2' if g['dx_03_codigo'] else None,
            'dx_03_codigo': g['dx_03_codigo'],
            'dx_03_descripcion': g['dx_03_descripcion'],
            'codigo_procedimiento': '99231', # Hospital stay CPT
            'descripcion_procedimiento': 'Estancia hospitalaria CPT',
            'fuentes': 'CPT',
            'MOTIVO': f"SOLAPAMIENTO E-H Group {g['group_id']}",
            'DECISION_AUDITORIA': 'SE UNE', # Default decision
            'OBSERVACION_AUDITORIA': ''
        })
        
    ws_eh = wb.active
    create_audit_sheet(ws_eh, "ESTANCIAS_E_H", eh_sheet_rows, '"SE UNE,NO SE UNE"')
    
    # Sheet 2: DUPLICADOS_FUENTES
    # Convert duplicate procedures/labs to sheet rows
    # Sorted by group_id and source to place CPT and SIGESAPOL contiguously
    dup_f_rows = []
    # Sort retained duplicates by group id
    retained_duplicates_sources.sort(key=lambda x: x[0]['dup_group_id'])
    for r, stype in retained_duplicates_sources:
        # Determine if CPT or SIGESAPOL
        is_sig = r.get('digitador_prestacion') == 'SIGESAPOL'
        default_decision = 'NO PROCEDE' if is_sig else 'PROCEDE' # default to keep CPT for pilot or vice-versa
        # Let's check canonico:
        # If month >= 10: SIGESAPOL is canonical, so default is PROCEDE for SIGESAPOL, NO PROCEDE for CPT
        if month >= 10:
            default_decision = 'PROCEDE' if is_sig else 'NO PROCEDE'
            
        dup_f_rows.append({
            'periodo': period,
            'tipo_atencion': str(r.get('sp_tipo_atencion')),
            'documento_paciente': r.get('sp_numero_documento_paciente'),
            'nombres_paciente': f"{r.get('sp_apellido_paterno_paciente')} {r.get('sp_apellido_materno_paciente')}, {r.get('sp_nombres_paciente')}",
            'fecha_ingreso': parse_date(r.get('sp_fecha_atencion')),
            'fecha_alta': parse_date(r.get('sp_fecha_alta')),
            'dx_01_tipo': r.get('sp_tipo_dx_01') or r.get('sp_tipo_diagnostico'),
            'dx_01_codigo': r.get('sp_codigo_dx_01') or r.get('sp_codigo_diagnostico'),
            'dx_01_descripcion': r.get('sp_descripcion_dx_01') or r.get('sp_descripcion_diagnostico'),
            'dx_02_tipo': r.get('sp_tipo_dx_02'),
            'dx_02_codigo': r.get('sp_codigo_dx_02'),
            'dx_02_descripcion': r.get('sp_descripcion_dx_02'),
            'dx_03_tipo': r.get('sp_tipo_dx_03'),
            'dx_03_codigo': r.get('sp_codigo_dx_03'),
            'dx_03_descripcion': r.get('sp_descripcion_dx_03'),
            'codigo_procedimiento': r.get('sp_codigo_procedimiento'),
            'descripcion_procedimiento': r.get('sp_descripcion_procedimiento'),
            'fuentes': 'SIGESAPOL' if is_sig else 'CPT',
            'MOTIVO': f"DUPLICADO ENTRE FUENTES Group {r['dup_group_id']}",
            'DECISION_AUDITORIA': default_decision,
            'OBSERVACION_AUDITORIA': ''
        })
        
    ws_df = wb.create_sheet()
    create_audit_sheet(ws_df, "DUPLICADOS_FUENTES", dup_f_rows, '"PROCEDE,NO PROCEDE"')
    
    # Sheet 3: DUPLICADOS_ORIGEN
    dup_o_rows = []
    duplicates_origin_list.sort(key=lambda x: x[0]['dup_group_id'])
    for r, stype in duplicates_origin_list:
        is_sig = r.get('digitador_prestacion') == 'SIGESAPOL'
        dup_o_rows.append({
            'periodo': period,
            'tipo_atencion': str(r.get('sp_tipo_atencion')),
            'documento_paciente': r.get('sp_numero_documento_paciente'),
            'nombres_paciente': f"{r.get('sp_apellido_paterno_paciente')} {r.get('sp_apellido_materno_paciente')}, {r.get('sp_nombres_paciente')}",
            'fecha_ingreso': parse_date(r.get('sp_fecha_atencion')),
            'fecha_alta': parse_date(r.get('sp_fecha_alta')),
            'dx_01_tipo': r.get('sp_tipo_dx_01') or r.get('sp_tipo_diagnostico'),
            'dx_01_codigo': r.get('sp_codigo_dx_01') or r.get('sp_codigo_diagnostico'),
            'dx_01_descripcion': r.get('sp_descripcion_dx_01') or r.get('sp_descripcion_diagnostico'),
            'dx_02_tipo': r.get('sp_tipo_dx_02'),
            'dx_02_codigo': r.get('sp_codigo_dx_02'),
            'dx_02_descripcion': r.get('sp_descripcion_dx_02'),
            'dx_03_tipo': r.get('sp_tipo_dx_03'),
            'dx_03_codigo': r.get('sp_codigo_dx_03'),
            'dx_03_descripcion': r.get('sp_descripcion_dx_03'),
            'codigo_procedimiento': r.get('sp_codigo_procedimiento'),
            'descripcion_procedimiento': r.get('sp_descripcion_procedimiento'),
            'fuentes': 'SIGESAPOL' if is_sig else 'CPT',
            'MOTIVO': f"DUPLICADO DE ORIGEN Group {r['dup_group_id']}",
            'DECISION_AUDITORIA': 'PROCEDE INDEPENDIENTE', # Default
            'OBSERVACION_AUDITORIA': ''
        })
    ws_do = wb.create_sheet()
    create_audit_sheet(ws_do, "DUPLICADOS_ORIGEN", dup_o_rows, '"CONSOLIDAR CANTIDAD,PROCEDE INDEPENDIENTE"')
    
    # Sheet 4: TRANSF_HUERFANAS
    ws_th = wb.create_sheet()
    create_audit_sheet(ws_th, "TRANSF_HUERFANAS", huerfanas_list, '"PROCEDE,NO PROCEDE"')
    
    # Sheet 5: LEYENDA
    ws_ley = wb.create_sheet(title="LEYENDA")
    ws_ley.append(['ESTADO', 'DECISION_AUDITORIA', 'DESCRIPCION'])
    ws_ley.append(['ESTANCIAS_E_H', 'SE UNE', 'Se unifica la estancia de emergencia con la de hospitalización (se amplía fecha de ingreso hosp. y se reincorpora el paquete de cobro de emergencia en hospitalización).'])
    ws_ley.append(['ESTANCIAS_E_H', 'NO SE UNE', 'Se rompe la unión. La emergencia vuelve a la trama Tipo 2 con código CPMS por prioridad y cantidad 1. Su paquete de cobro se factura en emergencia.'])
    ws_ley.append(['DUPLICADOS_FUENTES', 'PROCEDE', 'Se autoriza la inclusión de este registro en la trama correspondiente.'])
    ws_ley.append(['DUPLICADOS_FUENTES', 'NO PROCEDE', 'Se descarta el registro por completo de la facturación.'])
    ws_ley.append(['DUPLICADOS_ORIGEN', 'CONSOLIDAR CANTIDAD', 'Se consolidan las cantidades de los registros duplicados de origen en un solo registro de facturación sumando cantidades.'])
    ws_ley.append(['DUPLICADOS_ORIGEN', 'PROCEDE INDEPENDIENTE', 'Se envían los registros por separado a las tramas finales tal como están.'])
    ws_ley.append(['TRANSF_HUERFANAS', 'PROCEDE', 'Se aprueba el envío de la emergencia a facturación Tipo 2.'])
    ws_ley.append(['TRANSF_HUERFANAS', 'NO PROCEDE', 'Se elimina la emergencia de la facturación.'])
    
    wb.save(audit_path)
    print(f"Workbook successfully written to: {audit_path}")
    
    # Also write a standard controles_integridad.txt file in 03_INFORMATIVOS/
    # We can just write a short status summary
    with open(os.path.join(infos_dir, "controles_integridad.txt"), "w", encoding="utf-8") as f:
        f.write(f"PROCESAMIENTO DE REGISTROS V2 PARA PERIODO {period}\n")
        f.write(f"Fecha de Ejecucion: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("="*60 + "\n")
        f.write(f"Consulta Externa (LIMPIA): {len(final_consulta)} filas\n")
        f.write(f"Emergencia (LIMPIA): {len(final_emergencia)} filas\n")
        f.write(f"Hospitalización (LIMPIA): {len(final_hospitalizacion)} filas\n")
        f.write(f"Farmacia (LIMPIA): {len(final_farmacia)} filas\n")
        f.write(f"Estancias Pares E->H Retenidas (Caso A): {len(eh_groups)} pares\n")
        f.write(f"Registros de Paquete Retenidos: {len(excluded_package_emergencia) + len(excluded_package_hospitalizacion)} filas\n")
        f.write(f"Procedimientos Duplicados entre Fuentes Retenidos: {len(retained_duplicates_sources)} filas\n")
        f.write(f"Procedimientos Duplicados de Origen (Informativos): {len(duplicates_origin_list)} filas\n")
        f.write(f"Emergencias Huérfanas de Transferencia: {len(huerfanas_list)} filas\n")
        
    print("controles_integridad.txt summary written.")
    
    # 8. Generate metricas.json in 03_INFORMATIVOS/
    canonico = "CPT" if month < 10 else "SIGESAPOL"
    
    # Query duplicate stats
    cur.execute("""
        SELECT COUNT(*), COALESCE(SUM(sig.sp_valorizacion_calculada), 0)
        FROM temp_cpt_procedimientos_unificado cpt
        JOIN temp_sigesapol_procedimientos sig
          ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
         AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
         AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
         AND (   (sig.tipo_procedimiento = 1
                  AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
              OR (sig.tipo_procedimiento IN (2, 3)
                  AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) );
    """)
    dup_cnt, dup_val = cur.fetchone()
    
    metrics = {
        "periodo": period,
        "fuente_canonica": canonico,
        "volumenes_raw": {
            "consulta": len(consulta_raw),
            "emergencia": len(emergencia_raw),
            "hospitalizacion": len(hospitalizacion_raw),
            "farmacia": len(farmacia_raw)
        },
        "volumenes_tramas": {
            "trama_consulta_externa": len(final_consulta),
            "trama_emergencia": len(final_emergencia),
            "trama_hospitalizacion": len(final_hospitalizacion),
            "trama_farmacia": len(final_farmacia)
        },
        "deduplicacion": {
            "duplicados_ciertos": int(dup_cnt),
            "monto_evitado_doble_cobro": float(dup_val)
        },
        "observaciones": {
            "solapamientos_estancias": len(eh_groups),
            "duplicados_fuentes": len(retained_duplicates_sources) // 2,
            "duplicados_origen": len(duplicates_origin_list) // 2,
            "transiciones_huerfanas": len(huerfanas_list)
        },
        "conservacion": conservacion
    }
    
    with open(os.path.join(infos_dir, "metricas.json"), 'w', encoding='utf-8') as f:
        json.dump(metrics, f, indent=4)
        
    print("metricas.json successfully written.")
    
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
