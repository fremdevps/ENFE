create or replace package erp_gen_periodo_ctr
    authid definer
    accessible by (package erp_gen_periodo_reg, package erp_gen_periodo_api)
as
-- =============================================================================
-- Paquete : erp_gen_periodo_ctr   (capa ctr)
-- Tabla   : erp_gen_periodo
-- =============================================================================

    -- Registro vacío (periodo_id null) si no existe.
    function obtener (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type
    ) return erp_gen_periodo%rowtype;

    -- Inserta el período si no existe (idempotente).
    procedure insertar (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type,
        i_estado      in erp_gen_periodo.estado%type
    );

    procedure actualizar (
        i_periodo_id    in erp_gen_periodo.periodo_id%type,
        i_estado        in erp_gen_periodo.estado%type,
        i_fecha_cierre  in erp_gen_periodo.fecha_cierre%type,
        i_cerrado_por   in erp_gen_periodo.cerrado_por%type
    );

end erp_gen_periodo_ctr;
/
