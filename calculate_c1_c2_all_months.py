import subprocess
import psycopg2

def run_query(conn, query):
    cur = conn.cursor()
    cur.execute(query)
    res = cur.fetchone()
    cur.close()
    return res[0] if res else 0

months = [7, 8, 9, 10, 11, 12]
results = []

for m in months:
    month_pad = f"{m:02d}"
    print(f"Processing month: 2025-{month_pad}")
    
    # Run the month pipeline
    cmd = f"powershell -ExecutionPolicy Bypass -File ./run_month.ps1 -Year 2025 -Month {m}"
    subprocess.run(cmd, shell=True)
    
    # Connect to the database
    conn = psycopg2.connect("dbname=db_cpt_junio26 user=postgres password=root host=localhost")
    
    # Run queries
    # 1. Total emergencies
    total = run_query(conn, "SELECT count(*) FROM temp_emergencia_sigesapol_estancia;")
    
    # 2. Billed in emergency (tipo 2)
    tipo2 = run_query(conn, """
        SELECT count(*) FROM temp_emergencia_sigesapol_estancia e
        WHERE e.excluir_tipo2 = false
          AND NOT EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
              AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
          );
    """)
    
    # 3. Reclassified Caso B (PERMANENCIA_EMERGENCIA_24H)
    casoB = run_query(conn, "SELECT count(*) FROM temp_hospitalizacion_local WHERE origen_reclasificacion = 'PERMANENCIA_EMERGENCIA_24H';")
    
    # 4. United Caso A (UNION_EMERGENCIA_HOSP)
    casoA = run_query(conn, """
        SELECT COUNT(*) FROM temp_emergencia_sigesapol_estancia e
        WHERE e.excluir_tipo2 = true
          AND NOT (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15)
          AND EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
              AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
              AND (h.origen_reclasificacion IS NULL OR h.origen_reclasificacion = 'UNION_EMERGENCIA_HOSP')
          );
    """)
    
    # 5. Cierre Administrativo
    cierre = run_query(conn, """
        SELECT count(*) FROM temp_emergencia_sigesapol_estancia e
        WHERE e.excluir_tipo2 = true
          AND (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15);
    """)
    
    # 6. Excluidas por solapamiento
    solapadas = run_query(conn, """
        SELECT count(*) FROM temp_emergencia_sigesapol_estancia e
        WHERE e.excluir_tipo2 = false
          AND EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
              AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
          );
    """)
    
    # 7. C2 - Unidas con duracion <= 24h
    c2 = run_query(conn, """
        SELECT COUNT(*) FROM temp_hospitalizacion_local h
        JOIN temp_emergencia_sigesapol_estancia e ON h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
          AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
          AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
        WHERE h.origen_reclasificacion = 'UNION_EMERGENCIA_HOSP'
          AND (e.sp_fecha_alta_emergencia - e.sp_fecha_atencion) <= INTERVAL '24 hours';
    """)
    
    # --- BILLING MONTOS (ANTES VS DESPUES) ---
    # Baseline Hosp (origen_reclasificacion is null)
    h_est_base = run_query(conn, "SELECT COALESCE(SUM(sp_valorizacion_total), 0) FROM temp_hospitalizacion_local WHERE origen_reclasificacion IS NULL;")
    h_proc_base = run_query(conn, """
        SELECT COALESCE(SUM(bdt.valorizacion), 0) FROM temp_bdt_hospitalizacion_local bdt 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
          AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
        WHERE e.origen_reclasificacion IS NULL;
    """)
    h_lab_base = run_query(conn, """
        SELECT COALESCE(SUM(lab.valorizacion_total), 0) FROM temp_laboratorio_hospitalizacion_local lab 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
          AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
        WHERE e.origen_reclasificacion IS NULL;
    """)
    monto_hosp_base = h_est_base + h_proc_base + h_lab_base
    
    # Baseline Emer (no estancias reported originally, only proc and labs)
    e_proc_base = run_query(conn, """
        SELECT COALESCE(SUM(bdt.valorizacion), 0) FROM temp_bdt_emergencia_sigesapol bdt 
        JOIN temp_emergencia_sigesapol_estancia e ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
          AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date;
    """)
    e_lab_base = run_query(conn, """
        SELECT COALESCE(SUM(lab.valorizacion_total), 0) FROM temp_laboratorio_emergencia_sigesapol lab 
        JOIN temp_emergencia_sigesapol_estancia e ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
          AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date;
    """)
    monto_emer_base = e_proc_base + e_lab_base
    
    # Final Hosp
    h_est_final = run_query(conn, "SELECT COALESCE(SUM(sp_valorizacion_total), 0) FROM temp_hospitalizacion_local;")
    h_proc_final = run_query(conn, """
        SELECT COALESCE(SUM(bdt.valorizacion), 0) FROM temp_bdt_hospitalizacion_local bdt 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
          AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date;
    """)
    h_lab_final = run_query(conn, """
        SELECT COALESCE(SUM(lab.valorizacion_total), 0) FROM temp_laboratorio_hospitalizacion_local lab 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
          AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date;
    """)
    h_proc_reclass = run_query(conn, """
        SELECT COALESCE(SUM(bdt.valorizacion), 0) FROM temp_bdt_emergencia_sigesapol bdt 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
          AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
        WHERE e.origen_reclasificacion IS NOT NULL;
    """)
    h_lab_reclass = run_query(conn, """
        SELECT COALESCE(SUM(lab.valorizacion_total), 0) FROM temp_laboratorio_emergencia_sigesapol lab 
        JOIN temp_hospitalizacion_local e ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
          AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
        WHERE e.origen_reclasificacion IS NOT NULL;
    """)
    monto_hosp_final = h_est_final + h_proc_final + h_lab_final + h_proc_reclass + h_lab_reclass
    
    # Final Emer (estancias <= 24h facturadas + proc/labs excluding overlapping)
    # 1) Estancias <= 24h (tipo 2)
    e_est_final = run_query(conn, """
        SELECT COALESCE(SUM(
            CASE 
                WHEN e.prioridad = 1 THEN (SELECT nivel_3 FROM cpt WHERE cod_cpt = '99285' LIMIT 1)
                WHEN e.prioridad = 2 THEN (SELECT nivel_3 FROM cpt WHERE cod_cpt = '99284' LIMIT 1)
                WHEN e.prioridad = 3 THEN (SELECT nivel_3 FROM cpt WHERE cod_cpt = '99282' LIMIT 1)
                WHEN e.prioridad = 4 THEN (SELECT nivel_3 FROM cpt WHERE cod_cpt = '99281' LIMIT 1)
                ELSE 15.31
            END
        ), 0)
        FROM temp_emergencia_sigesapol_estancia e
        WHERE e.excluir_tipo2 = false
          AND NOT EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
              AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
          );
    """)
    # 2) Procedures
    e_proc_final = run_query(conn, """
        SELECT COALESCE(SUM(bdt.valorizacion), 0) FROM temp_bdt_emergencia_sigesapol bdt 
        JOIN temp_emergencia_sigesapol_estancia e ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
          AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
        WHERE e.excluir_tipo2 = false
          AND NOT EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND bdt.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
          );
    """)
    # 3) Labs
    e_lab_final = run_query(conn, """
        SELECT COALESCE(SUM(lab.valorizacion_total), 0) FROM temp_laboratorio_emergencia_sigesapol lab 
        JOIN temp_emergencia_sigesapol_estancia e ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
          AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
        WHERE e.excluir_tipo2 = false
          AND NOT EXISTS (
            SELECT 1 FROM temp_hospitalizacion_local h
            WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
              AND lab.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
          );
    """)
    monto_emer_final = e_est_final + e_proc_final + e_lab_final
    
    conn.close()
    
    # Verify sum
    calculated_sum = tipo2 + casoB + casoA + cierre + solapadas
    residuo = total - calculated_sum
    
    print(f"  Total: {total}, Sum: {calculated_sum}, Residuo: {residuo}, C2: {c2}")
    print(f"  Billing - Emer Base: S/. {monto_emer_base:,.2f}, Emer Final: S/. {monto_emer_final:,.2f}")
    print(f"  Billing - Hosp Base: S/. {monto_hosp_base:,.2f}, Hosp Final: S/. {monto_hosp_final:,.2f}")
    net_gain = (monto_emer_final + monto_hosp_final) - (monto_emer_base + monto_hosp_base)
    print(f"  Net Gain: S/. {net_gain:,.2f}")
    results.append({
        'month': f"2025-{month_pad}",
        'total': total,
        'tipo2': tipo2,
        'casoB': casoB,
        'casoA': casoA,
        'cierre': cierre,
        'solapadas': solapadas,
        'c2': c2,
        'residuo': residuo
    })

print("\nFinal Results Table:")
print("| Month | Total Stays | Tipo 2 Facturadas | Caso B Reclass | Caso A Unidas | Cierre Admin | Excluidas Solap | Residuo | C2 (<=24h) |")
print("|---|---|---|---|---|---|---|---|---|")
for r in results:
    print(f"| {r['month']} | {r['total']} | {r['tipo2']} | {r['casoB']} | {r['casoA']} | {r['cierre']} | {r['solapadas']} | {r['residuo']} | {r['c2']} |")
