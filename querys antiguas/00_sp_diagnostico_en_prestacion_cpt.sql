/* =======================================
Procedimiento almacenado para obtener los diagnósticos activos de una prestación de salud - hospitalización.
== Parámetros a enviar: 	
  p_id_prestacion_cpt: id de prestación de la tabla prestacion_cpt

 =======================================
*/

--DROP FUNCTION sp_diagnostico_en_prestacion_cpt(p_id_prestacion_cpt integer);

CREATE OR REPLACE FUNCTION sp_diagnostico_en_prestacion_cpt(
	p_id_prestacion_cpt integer
)
RETURNS TABLE (
	id_prestacion_cpt integer,
	tipo_diagnostico character varying(1),
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	estado character varying(1),
	orden integer
) 
AS $$ 
BEGIN
RETURN QUERY 

SELECT dx.id_prestacion_cpt,
	(CASE 
		when dx.tipo_diagnostico_cpt = 'P - PRESUNTIVO' then '1' 
		when dx.tipo_diagnostico_cpt = 'D - DEFINITIVO' then '2'
		when dx.tipo_diagnostico_cpt = 'R - REPETITIVO' then '3'
		else '2' -- Se indica que se coloque definitivo
	END)::character varying(1) as tipo_diagnostico,
	c.codigo as codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,
	dx.estado,
	ROW_NUMBER() OVER(ORDER BY dx.id_diagnostico_cpt)::integer AS orden
FROM diagnostico_cpt dx
INNER JOIN cie10 c ON dx.id_cie10 = c.id_cie10
WHERE dx.id_prestacion_cpt = p_id_prestacion_cpt
	AND dx.estado = 'N';
END; $$

language 'plpgsql';

-- SELECT * FROM sp_diagnostico_en_prestacion_cpt(22408)