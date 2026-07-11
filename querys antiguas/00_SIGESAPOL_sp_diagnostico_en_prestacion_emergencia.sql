/* =======================================
Procedimiento almacenado para obtener los diagnósticos activos de una prestación de salud - hospitalización.
== Parámetros a enviar: 	
  p_id_prestacion_emergencia: id de prestación de la tabla atencion_emergencia

 =======================================
*/

--DROP FUNCTION sp_diagnostico_en_prestacion_emergencia(p_id_prestacion_emergencia integer);

CREATE OR REPLACE FUNCTION sp_sigesapol_diagnostico_en_prestacion_emergencia(
	p_id_prestacion_emergencia integer
)
RETURNS TABLE (
	id_prestacion integer,
	tipo_diagnostico character varying(1),
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	orden integer
) 
AS $$ 
BEGIN
RETURN QUERY 

SELECT 	--dx.id,
	dx.id_prestacion,
	dx.id_tipo_diagnostico::character varying(1) as tipo_diagnostico,
	cie.codigo AS codigo_diagnostico,
	--UPPER(cie.nombre) as descripcion_diagnostico,
	UPPER(regexp_replace(cie.nombre, '\r|\n|\t', '', 'g')) as descripcion_diagnostico,
	ROW_NUMBER() OVER(ORDER BY dx.id)::integer AS orden
FROM receta_diagnosticos dx
INNER JOIN diagnosticos cie ON cie.id = dx.id_diagnostico
WHERE dx.id_prestacion = p_id_prestacion_emergencia;
END; $$

language 'plpgsql';

-- SELECT * FROM sp_sigesapol_diagnostico_en_prestacion_emergencia(1349961)