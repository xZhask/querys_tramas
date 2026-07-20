-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 12_SIGESAPOL_farmacia.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================
-- TRAMA GENERAL PARA ARMAR LAS TRAMAS I, II, III, IV
--/**********************************************************/
--/**********************************************************/

select 
--(rv.dni_beneficiario ||'_'||e.codigo||'_'||to_char(rv.fecha_expedicion, 'yyyymmdd')||'_'||m.dni)::varchar PK, to_char(rv.fecha_expedicion, 'yyyymm') anomes_produccion,
--to_char(rv.fecha_expedicion, 'yyyymmdd') anomesdia_produccion,
(Case When rv.tipodoc_beneficiario='DNI' Then '1' When rv.tipodoc_beneficiario='CE' Then '2' End)::varchar paciente_tipo_documento,
(rv.dni_beneficiario)::text as paciente_numero_documento,
rv.paterno_beneficiario, rv.materno_beneficiario, rv.nombre_beneficiario,
(Case When rv.fecha_nacimiento_beneficiario ='' Then a.fecha_nac else rv.fecha_nacimiento_beneficiario End)::varchar fecha_nacimiento_pnp,
(Case When rv.sexo_beneficiario ='' Then (Case When a.sexo ='M' Then '1' When a.sexo ='F' Then '2' End) When rv.sexo_beneficiario ='M' Then '1' When rv.sexo_beneficiario ='F' Then '2' End)::varchar sexo_paciente,
(Case When rv.tipo_beneficiario ='TITULAR' Then '1' else '2' End)::varchar tipo_beneficiario_pnp,
(Case 	When rv.tipo_receta = 'AMBULATORIO' then '1'
	When rv.tipo_receta = 'EMERGENCIA' then '2'
	When rv.tipo_receta = 'HOSPITALIZACION' then '3'
End) as tipo_atencion,
e.codigo ipress_codigo, e.nombre eess,
rv.fecha_registro fecha_atencion_medica, rv.fecha_expedicion fecha_dispensacion,
(m.dni)::text as dni_medico, m.paterno as paterno_medico, m.materno as materno_medico, m.nombre as nomb_medico,

-- ===> profesión y especialidad
prof.nombre AS sp_nombre_profesion_responsable,

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

(CASE WHEN es.nombre = 'OBSTETRICIA' then '00' else '01' end)::varchar sp_codigo_especialidad,

rv.fecha_expedicion fecha_dispensacion_como_atencion, -- línea 15
-- ===> CONSULTA EXTERNA
''::text AS sp_fecha_alta, ''::text AS sp_circunstancia_alta,

-- ===> EMERGENCIA LOCAL Y SIGESAPOL
--emerg.sp_fecha_alta_emergencia, emerg.sp_circunstancia_alta_sigesapol_sp,

-- ===> HOSPITALIZACION
--hospi.sp_fecha_alta, hospi.sp_circunstancia_alta,

--(case when es.nombre='ODONTOLOGIA' then '03' else '01' end)::varchar codigo_especialidad,es.nombre as especialidad_medico,
rv.codigo_upss,c.nombre as servicio,
(case when rv.tipo_receta='HOSPITALIZACION' then '1' else '2' end)::VARCHAR Hospitalizacion,
( case when rd.id_tipo_diagnostico isnull then '1' else rd.id_tipo_diagnostico end)::varchar id_tipo_diagnostico,
d.codigo as cod_dx, d.nombre as diagnostico, d.genero,
(u.dni)::text as dni_dispensacion, u.paterno as paterno_dispensacion, u.materno as materno_dispensacion, u.name as nomb_dispensador,
(Case When p.id_tipo=1 Then 'C' When p.id_tipo In(2,3,4,5) Then 'I' When p.id_tipo In(6,7,8) Then 'O' End)::varchar tipo,
t.nombre as tipo_producto,
p.codigo cod_petitorio, -- usado en el sigesapol
p.nombre as principio_activo, --usado en el sigesapol
p.cod_trama, p.desc_trama, -- usado para las tramas a partir del mes de marzo 2023
Sum(pr.cantidad_dispensada)cantidad,
k.precio_unitario,
p.precio_trama as precio_ejecutora,

(Case When p.precio_trama >0 Then p.precio_trama else k.precio_unitario End)::float precio_trama,
(Case When p.precio_trama >0 Then SUM(pr.cantidad_dispensada*p.precio_trama) else SUM(pr.cantidad_dispensada*k.precio_unitario) End)::float Valorizado_1,
'99199.05'::varchar codigo_procedimiento,
'Dispensación de medicamentos, dispositivos médicos y productos farmacéuticos'::varchar nombre_procedimiento,
'6.89'::float precio_tarifario_procedimiento
--(Case When p2.codigo is null Then '99199.05' Else p2.codigo end)::varchar codigo_procedimiento,
--(Case When p2.codigo is null Then 'Dispensación de medicamentos, dispositivos médicos y productos farmacéuticos' Else p2.descripcion End)::varchar nombre_procedimiento,
--(Case When p2.codigo is null Then 6.89 else (Case When e.nivel='1' Then p2.t_nivel1 When e.nivel='2' Then p2.t_nivel2 When e.nivel='3' Then p2.t_nivel3 End) End)::float precio_tarifario_procedimiento

From receta_vales rv

left join prestaciones pre on rv.id_prestacion = pre.id
left join asegurados a on a.id = pre.id_asegurado
--left join prestacion_procedimientos pp on pp.id_prestacion = pre.id
--left join procedimientos p2 on p2.id = pp.id_procedimiento
--inner Join producto_recetas pr On rv.id=pr.id_receta_vale
left Join producto_recetas pr On rv.id=pr.id_receta_vale
--inner Join productos p On pr.id_producto=p.id
left Join productos p On pr.id_producto=p.id
--inner join tipo_productos t on t.id=p.id_tipo
LEFT join tipo_productos t on t.id=p.id_tipo
inner Join farmacias f On rv.id_farmacia=f.id
inner Join establecimientos e On f.id_establecimiento=e.id
inner join medicos m on m.id=rv.id_medico
inner join users u on u.id=rv.id_user
inner join especializaciones es on es.id = m.id_especializacion
inner join consultorios c on c.id = rv.id_consultorio
left join receta_diagnosticos rd on rd.id_receta_vale= rv.id
left join diagnosticos d on d.id= rd.id_diagnostico
left join tipo_diagnosticos td on td.id=rd.id_tipo_diagnostico

-- ===> profesiones
INNER JOIN profesiones prof on prof.id = m.id_profesion

-- EMERGENCIA LOCAL
--inner join temp_emergencia_dirsapol emerg on emerg.sp_numero_documento_paciente = rv.dni_beneficiario
-- EMERGENCIA SIGESAPOL
--inner join temp_emergencia_sigesapol_estancia emerg on emerg.sp_numero_documento_paciente = rv.dni_beneficiario
-- HOSPITALIZACIÓN
--inner join temp_hospitalizacion_local hospi on hospi.sp_numero_documento_paciente = rv.dni_beneficiario

left join
(

Select k.id_nro_movimiento,k.id_producto,Sum(kl.cantidad)cantidad, round(Cast(Avg(kl.precio_unitario)As numeric),5)precio_unitario

From kardexes k Inner Join kardex_lotes kl On k.id=kl.id_kardex And k.id_tipo_movimiento=4 And

k.numero_movimiento Not Like '%-i'

Group By k.id_nro_movimiento,k.id_producto

)k On rv.id=k.id_nro_movimiento And pr.id_producto=k.id_producto

where rv.estado=1 And pr.cantidad_dispensada>0 and p.petitorio ='SI'

and e.id = (SELECT id_establecimiento_sigesapol FROM cfg_ipress_alcance) -- ALCANCE: solo Hospital Luis N. Saenz

-- CONSULTA EXTERNA
and rv.tipo_receta IN ('AMBULATORIO', 'SERVICIO NUTRICIONAL - AMBULATORIO', 'URGENCIA')
and rv.fecha_expedicion::date between (SELECT p_ini FROM cfg_periodo) and (SELECT p_fin FROM cfg_periodo)

-- EMERGENCIA LOCAL Y SIGESAPOL
--and (rv.tipo_receta = 'EMERGENCIA')
--and rv.fecha_expedicion::date between emerg.sp_fecha_atencion and emerg.sp_fecha_alta_emergencia

-- HOSPITALIZACIÓN
--and rv.tipo_receta IN ('HOSPITALIZACION', 'SERVICIO NUTRICIONAL - HOSPITALIZACION', 'ONCOLOGICO - HOSPITALIZACION')
--and rv.fecha_expedicion::date between hospi.sp_fecha_atencion::date and hospi.sp_fecha_alta::date


Group by rv.tipodoc_beneficiario, rv.dni_beneficiario, rv.tipo_beneficiario, rv.paterno_beneficiario,
rv.materno_beneficiario, rv.nombre_beneficiario, rv.tipo_receta, rv.fecha_registro, rv.fecha_expedicion, rv.nro_receta, u.dni,
u.paterno, u.materno, u.name,m.dni,m.paterno, m.materno, m.nombre, es.nombre, c.nombre, d.codigo, d.nombre, rd.id_tipo_diagnostico, p.id_tipo,
t.nombre, p.codigo, p.nombre, k.precio_unitario, e.codigo, e.nombre, d.genero, rv.sexo_beneficiario, rv.fecha_nacimiento_beneficiario, p.petitorio,
--p2.codigo, p2.descripcion, p2.t_nivel1, p2.t_nivel2, p2.t_nivel3, 
a.sexo , a.fecha_nac, rv.codigo_upss, p.cod_trama,p.desc_trama, p.precio_trama, e.nivel
-- ==> prof nombre
, prof.nombre
-- ===> EMERGENCIA - LOCAL Y SIGESAPOL
--, emerg.sp_fecha_alta_emergencia, emerg.sp_circunstancia_alta_sigesapol_sp
-- ===> HOSPITALIZACION
--, hospi.sp_fecha_alta, hospi.sp_circunstancia_alta
;

