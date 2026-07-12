-- ============================================================================
-- 02_MAESTRO_paso1_SIGESAPOL.sql
-- PASO 1 del armado mensual: estancias de emergencia desde SIGESAPOL.
-- Correr en la BD SIGESAPOL.
--
-- >>> EL PERÍODO SE DECLARA UNA SOLA VEZ, AQUÍ ABAJO. <<<
-- Es el único lugar de todo el paso 1 donde se escriben fechas.
--
-- Reemplaza al archivo original "10_SIGESAPOL_SALUDPOL_emergencia_2023_estancia"
-- con tres mejoras:
--   1. Período parametrizado vía tabla cfg_periodo (adiós fechas dispersas).
--   2. DROP TABLE IF EXISTS: re-ejecutable mes a mes sin borrar nada a mano.
--   3. Filtro e.estado = 5: elimina los 21 registros anómalos con alta médica
--      pero estado inválido detectados en el CHECK 14 (15 anuladas + otros).
-- El SELECT es idéntico al original en columnas y lógica.
-- ============================================================================

-- ========================= CONFIGURAR PERÍODO AQUÍ =========================
DROP TABLE IF EXISTS cfg_periodo;
CREATE TABLE cfg_periodo AS
SELECT DATE '2025-12-01' AS p_ini,   -- <== inicio del periodo
       DATE '2025-12-31' AS p_fin;   -- <== fin del período
-- ============================================================================


DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia;

CREATE TABLE temp_emergencia_sigesapol_estancia AS
SELECT
	'SIGESAPOL emergencia estancia'::text AS base,
	CASE
		WHEN a.tipo_doc_ident = 'DNI' THEN '1'::varchar
		WHEN a.tipo_doc_ident = 'CE' THEN '2'::varchar
	END AS sp_tipo_documento_paciente,
	a.nro_doc_ident AS sp_numero_documento_paciente,
	a.paterno AS sp_apellido_paterno_paciente,
	a.materno AS sp_apellido_materno_paciente,
	a.nombre AS sp_nombres_paciente,
	a.fecha_nac AS sp_fecha_nacimiento_paciente,
	CASE
		WHEN a.sexo = 'M' THEN '1'::varchar
		WHEN a.sexo = 'F' THEN '2'::varchar
	END AS sp_genero_paciente,
	CASE
		WHEN e.id_tipo_parentesco = 8 THEN '1'::varchar -- titular
		ELSE '2'::varchar
	END AS sp_condicion_asegurado,
	'2'::text AS sp_tipo_atencion,
	es.codigo AS sp_codigo_ipress,
	es.nombre AS sp_nombre_ipress,
	COALESCE(e.fecha_atencion, e.created_at) sp_fecha_atencion,
	e.fecha_alta_medica as sp_fecha_alta_emergencia,

	(CASE WHEN m.tipo_documento IS NULL then '1' else m.tipo_documento end)::varchar sp_tipo_documento_responsable,
	m.dni AS sp_numero_documento_responsable,
	m.paterno AS sp_apellido_paterno_responsable,
	m.materno AS sp_apellido_materno_responsable,
	m.nombre AS sp_nombres_responsable,

	prof.nombre AS sigesapol_nombre_profesion_responsable,
	(CASE 	WHEN prof.nombre = 'MEDICO GENERAL' THEN 'MÉDICO'
		WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN 'MÉDICO'
		WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN 'QUÍMICO'
		WHEN prof.nombre = 'ODONTOLOGIA' THEN 'ODONTÓLOGO'
		WHEN prof.nombre = 'OBSTETRICIA' THEN 'OBSTETRA'
		WHEN prof.nombre = 'ENFERMERIA' THEN 'ENFERMERÍA'
		WHEN prof.nombre = 'PSICOLOGIA' THEN 'PSICÓLOGOS'
		WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN 'TECNÓLOGOS MÉDICOS'
		WHEN prof.nombre = 'NUTRICIONISTA' THEN 'NUTRICIONISTA'
		WHEN prof.nombre = 'MEDICO CIRUJANO' THEN 'MÉDICO'
		WHEN prof.nombre = 'MEDICO' THEN 'MÉDICO'
		WHEN prof.nombre = 'OFTALMOLOGIA' THEN 'MÉDICO'
		WHEN prof.nombre = 'GINECOLOGIA' THEN 'MÉDICO'
		WHEN prof.nombre = 'BIOLOGO' THEN 'BIÓLOGO'
	ELSE 'OTRO PROFESIONAL DE LA SALUD'
	END
	) AS sp_nombre_profesion_responsable,
	(CASE 	WHEN prof.nombre = 'MEDICO GENERAL' THEN '01'
		WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN '01'
		WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN '02'
		WHEN prof.nombre = 'ODONTOLOGIA' THEN '03'
		WHEN prof.nombre = 'OBSTETRICIA' THEN '05'
		WHEN prof.nombre = 'ENFERMERIA' THEN '06'
		WHEN prof.nombre = 'PSICOLOGIA' THEN '07'
		WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN '09'
		WHEN prof.nombre = 'NUTRICIONISTA' THEN '10'
		WHEN prof.nombre = 'MEDICO CIRUJANO' THEN '01'
		WHEN prof.nombre = 'MEDICO' THEN '01'
		WHEN prof.nombre = 'OFTALMOLOGIA' THEN '01'
		WHEN prof.nombre = 'GINECOLOGIA' THEN '01'
		WHEN prof.nombre = 'BIOLOGO' THEN '04'
	ELSE '00'
	END
	) AS sp_codigo_profesion_responsable,

	(CASE WHEN esp.nombre = 'OBSTETRICIA' then '00' else '01' end)::varchar sp_codigo_especialidad,
	regexp_replace(esp.nombre, '\r|\n|\t', '', 'g') as nombre_especialidad,
	e.id_condi_egres_med AS sp_circunstancia_alta_sigesapol_sp,
	cond.codigo_salupol AS condicion_alta,
	e.id_prioridad prioridad,
	e.estado,

	'230000'::varchar as sp_upss_codigo,
	'EMERGENCIA'::varchar as sp_upss_nombre,
	'2'::varchar AS hospitalizacion,

	'2'::varchar AS sp_tipo_dx_01,
	d1.codigo AS sp_codigo_dx_01,
	d1.nombre AS sp_descripcion_dx_01,
	'2'::varchar AS sp_tipo_dx_02,
	d2.codigo AS sp_codigo_dx_02,
	d2.nombre AS sp_descripcion_dx_02,
	'2'::varchar AS sp_tipo_dx_03,
	d3.codigo AS sp_codigo_dx_03,
	d3.nombre AS sp_descripcion_dx_03,

	e.id as id_emergencia_sigesapol,
	-- CPMS de alta: el 22.5% viene vacío (check 26 del piloto). Fallback por
	-- prioridad con LA MISMA convención del sistema legado ("UNITIC
	-- regularizará"): prioridad I -> 99295 (UCI día-paciente),
	-- II/III y demás -> 99231.15 (hosp. especializada continuada).
	COALESCE(NULLIF(e.cpms_alta, ''),
		CASE
			WHEN pr.descripcion ILIKE 'I -%' OR pr.descripcion ILIKE 'I %' THEN '99295'
			ELSE '99231.15'
		END) as cpms_alta,
	(COALESCE(e.cpms_alta, '') = '') AS es_cpms_derivado, -- true = código derivado por prioridad
	pr.descripcion AS prioridad_descripcion, -- trazabilidad del fallback
	(date(e.fecha_alta_medica) - date(e.fecha_atencion) + 1) as cantidad_cpms_estancia

  FROM emergencias e
  LEFT JOIN asegurados a ON a.id = e.id_asegurado
	inner join users u on u.id = e.id_medico_egreso and u.status = 1
	left join
	(select * from (
		select *, row_number() over (
			partition by dni
			order by id desc
			) as row_num
		from medicos
		) as medicos_ordenados
		where medicos_ordenados.row_num = 1
	) as m
	on m.dni = u.dni
  INNER JOIN establecimientos es ON es.id = e.id_establecimiento
  INNER JOIN profesiones prof on prof.id = m.id_profesion
  INNER JOIN especializaciones esp on esp.id = m.id_especializacion
  left join condiciones cond on cond.id = e.id_condi_egres_med
  LEFT JOIN prioridades pr ON pr.id = e.id_prioridad -- para el fallback de CPMS
  LEFT JOIN diagnosticos d1 ON d1.id = e.id_diag_cab
  LEFT JOIN diagnosticos d2 ON d2.id = e.id_diag_cuer1
  LEFT JOIN diagnosticos d3 ON d3.id = e.id_diag_cuer2

  where e.fecha_alta_medica is not null
  and e.estado = 5   -- FIX: solo emergencias válidas/cerradas (CHECK 14)
  and e.fecha_alta_medica::date between (SELECT p_ini FROM cfg_periodo)
                                    and (SELECT p_fin FROM cfg_periodo)

Group by
a.tipo_doc_ident, a.nro_doc_ident, a.paterno, a.materno, a.nombre,
a.fecha_nac, a.sexo, e.id_tipo_parentesco,
es.codigo, es.nombre, e.id_prioridad,
m.tipo_documento, m.dni, m.paterno, m.materno, m.nombre,
prof.nombre, esp.nombre,
cond.codigo_salupol, e.estado, e.id_condi_egres_med,
e.fecha_atencion, e.fecha_alta_medica,
e.cpms_alta, pr.descripcion,
e.id, a.id,
d1.codigo, d1.nombre, d2.codigo, d2.nombre, d3.codigo, d3.nombre

order by a.id;


-- Verificación rápida post-creación:
SELECT COUNT(*) AS estancias_emergencia,
       MIN(sp_fecha_atencion) AS primera_atencion,
       MAX(sp_fecha_alta_emergencia) AS ultima_alta,
       COUNT(*) FILTER (WHERE sp_numero_documento_paciente IS NULL) AS sin_documento
FROM temp_emergencia_sigesapol_estancia;
-- "sin_documento" > 0 => emergencias sin asegurado vinculado (LEFT JOIN):
-- revisar antes de continuar, porque no cruzarán con los procedimientos CPT.


-- ============================================================================
-- TRASLADO A LA BD CPT
-- La tabla temp_emergencia_sigesapol_estancia debe existir en la BD CPT antes
-- del paso 2 (las funciones 03/04 modo 22 la consultan).
--
-- Si SIGESAPOL y CPT están en el MISMO servidor PostgreSQL (distintas BD),
-- desde la terminal:
--
--   pg_dump -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia | psql -U postgres -d db_cpt_junio26
--
-- (si la tabla ya existe en CPT de un mes anterior, primero en CPT:
--   DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia;)
--
-- Alternativa permanente: configurar postgres_fdw para que CPT lea la tabla
-- de SIGESAPOL directamente. Consultar cómo lo hace hoy el equipo LNS.
-- ============================================================================
