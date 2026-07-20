-- ==============================================================================
-- CONSULTAS DE OBSERVACIÓN — AUDITORÍA MÉDICA (Reemplazo Visual)
-- ==============================================================================
-- Este archivo contiene las consultas SQL que emulan el comportamiento del 
-- aplicativo Python (generate_outputs_v2.py) para que puedan ser ejecutadas 
-- y visualizadas directamente en la grilla de PgAdmin.
-- 
-- NOTA: La versión oficial y procesable para Auditoría Médica, junto con
-- la lógica de reincorporación (script 13), es exclusiva del aplicativo Python.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ESTANCIAS E->H (Caso A)
-- Lista de transiciones de emergencia a hospitalización detectadas (solapamiento o <= 24h).
-- Emula la pestaña ESTANCIAS_E_H del libro de auditoría.
-- ------------------------------------------------------------------------------
SELECT
    e.id_emergencia_sigesapol AS "ID Emergencia",
    h.id_prestacion_cpt AS "ID Hospitalización",
    e.sp_numero_documento_paciente AS "DNI Paciente",
    e.sp_apellido_paterno_paciente || ' ' || e.sp_apellido_materno_paciente || ', ' || e.sp_nombres_paciente AS "Nombre Paciente",
    e.sp_fecha_atencion AS "Ingreso EME",
    e.sp_fecha_alta_emergencia AS "Alta EME",
    h.sp_fecha_atencion AS "Ingreso HOSP (Local)",
    h.sp_fecha_alta AS "Alta HOSP (Local)",
    e.prioridad AS "Prioridad",
    e.sp_codigo_dx_01 AS "DX 1", e.sp_descripcion_dx_01 AS "Desc DX 1",
    e.sp_codigo_dx_02 AS "DX 2", e.sp_descripcion_dx_02 AS "Desc DX 2",
    e.sp_codigo_dx_03 AS "DX 3", e.sp_descripcion_dx_03 AS "Desc DX 3",
    h.row_uid AS "UID Hosp"
FROM temp_hospitalizacion_local h
JOIN temp_emergencia_sigesapol_estancia e 
  ON e.id_emergencia_sigesapol = h.id_emergencia_unida
WHERE h.origen_reclasificacion = 'UNION_EMERGENCIA_HOSP';

-- ------------------------------------------------------------------------------
-- 2. TRANSFERENCIAS HUÉRFANAS
-- Emergencias con condición de alta 3 (Transferencia) sin estancia hospitalaria de destino.
-- Emula la pestaña TRANSF_HUERFANAS del libro de auditoría.
-- ------------------------------------------------------------------------------
SELECT 
    e.id_emergencia_sigesapol AS "ID Emergencia",
    e.sp_numero_documento_paciente AS "DNI Paciente",
    e.sp_apellido_paterno_paciente || ' ' || e.sp_apellido_materno_paciente || ', ' || e.sp_nombres_paciente AS "Nombre Paciente",
    e.sp_fecha_atencion AS "Ingreso EME",
    e.sp_fecha_alta_emergencia AS "Alta EME",
    e.prioridad AS "Prioridad",
    e.sp_codigo_dx_01 AS "DX 1", e.sp_descripcion_dx_01 AS "Desc DX 1",
    e.sp_codigo_dx_02 AS "DX 2", e.sp_descripcion_dx_02 AS "Desc DX 2",
    e.sp_codigo_dx_03 AS "DX 3", e.sp_descripcion_dx_03 AS "Desc DX 3"
FROM temp_emergencia_sigesapol_estancia e
WHERE e.condicion_alta = 3
  AND NOT EXISTS (
    SELECT 1 FROM temp_hospitalizacion_local h
    WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
      AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
      AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
  );

-- ------------------------------------------------------------------------------
-- 3. DUPLICADOS POR TIPO (CE: Tipo 1)
-- Detecta duplicados en consulta externa (agrupación: paciente + fecha + código + médico)
-- ------------------------------------------------------------------------------
SELECT 
    sp_numero_documento_paciente AS "DNI Paciente", 
    sp_fecha_atencion::date AS "Fecha", 
    sp_codigo_procedimiento AS "CPMS", 
    sp_descripcion_procedimiento AS "Procedimiento",
    sp_numero_documento_responsable AS "DNI Médico",
    COUNT(*) AS "Ocurrencias",
    STRING_AGG(digitador_prestacion, ' | ') AS "Fuentes"
FROM temp_bdt_consulta_local
GROUP BY 
    sp_numero_documento_paciente, 
    sp_fecha_atencion::date, 
    sp_codigo_procedimiento, 
    sp_descripcion_procedimiento,
    sp_numero_documento_responsable
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------------------------
-- 4. DUPLICADOS POR TIPO (EMERGENCIA: Tipo 2)
-- Detecta duplicados en emergencia (agrupación: paciente + fecha + código + cantidad)
-- Excluye las estancias.
-- ------------------------------------------------------------------------------
SELECT 
    sp_numero_documento_paciente AS "DNI Paciente", 
    sp_fecha_atencion::date AS "Fecha", 
    sp_codigo_procedimiento AS "CPMS", 
    sp_descripcion_procedimiento AS "Procedimiento",
    sp_suma_cantidad AS "Cantidad",
    COUNT(*) AS "Ocurrencias",
    STRING_AGG(digitador_prestacion, ' | ') AS "Fuentes"
FROM temp_bdt_emergencia_local
WHERE base NOT LIKE '%estancia%'
GROUP BY 
    sp_numero_documento_paciente, 
    sp_fecha_atencion::date, 
    sp_codigo_procedimiento, 
    sp_descripcion_procedimiento,
    sp_suma_cantidad
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------------------------
-- 5. DUPLICADOS POR TIPO (HOSPITALIZACIÓN: Tipo 3)
-- Detecta duplicados en hospitalización (agrupación: paciente + fecha + código + cantidad)
-- Excluye las estancias.
-- ------------------------------------------------------------------------------
SELECT 
    sp_numero_documento_paciente AS "DNI Paciente", 
    sp_fecha_atencion::date AS "Fecha", 
    sp_codigo_procedimiento AS "CPMS", 
    sp_descripcion_procedimiento AS "Procedimiento",
    sp_suma_cantidad AS "Cantidad",
    COUNT(*) AS "Ocurrencias",
    STRING_AGG(digitador_prestacion, ' | ') AS "Fuentes"
FROM temp_bdt_hospitalizacion_local
WHERE base NOT LIKE '%estancia%'
GROUP BY 
    sp_numero_documento_paciente, 
    sp_fecha_atencion::date, 
    sp_codigo_procedimiento, 
    sp_descripcion_procedimiento,
    sp_suma_cantidad
HAVING COUNT(*) > 1;
