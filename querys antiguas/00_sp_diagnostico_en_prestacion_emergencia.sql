/* =======================================
Procedimiento almacenado para obtener los diagnósticos activos de una prestación de salud - hospitalización.
== Parámetros a enviar: 	
  p_id_prestacion_emergencia: id de prestación de la tabla atencion_emergencia

 =======================================
*/

--DROP FUNCTION sp_diagnostico_en_prestacion_emergencia(p_id_prestacion_emergencia integer);

CREATE OR REPLACE FUNCTION sp_diagnostico_en_prestacion_emergencia(
	p_id_prestacion_emergencia integer
)
RETURNS TABLE (
	id_atencion_emergencia integer,
	tipo_diagnostico character varying(1),
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	orden integer
) 
AS $$ 
BEGIN
RETURN QUERY 

SELECT dx.id_atencion_emergencia,
	(CASE 
		when dx.tipo = 'P - PRESUNTIVO' then '1' 
		when dx.tipo = 'D - DEFINITIVO' then '2'
		when dx.tipo = 'R - REPETITIVO' then '3'
		else '2' -- Se indica que se coloque definitivo
	END)::character varying(1) as tipo_diagnostico,
	c.codigo as codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,
	ROW_NUMBER() OVER(ORDER BY dx.id_atencion_emergencia)::integer AS orden
FROM diagnostico dx
INNER JOIN cie10 c ON dx.id_cie10 = c.id_cie10
WHERE dx.id_atencion_emergencia = p_id_prestacion_emergencia;
END; $$

language 'plpgsql';

-- SELECT * FROM sp_diagnostico_en_prestacion_emergencia(348667)