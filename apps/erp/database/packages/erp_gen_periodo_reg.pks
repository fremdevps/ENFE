create or replace package erp_gen_periodo_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_periodo_reg   (capa reg)
-- Desc    : Control de períodos abiertos/cerrados por empresa y módulo.
--           Período sin registro = abierto, salvo que el parámetro
--           ERP_GEN_PERIODO_ESTRICTO = 'S' (entonces debe existir y estar abierto).
--           Un período cerrado admite registros del usuario de la sesión si tiene
--           una habilitación vigente (erp_gen_periodo_habilita).
-- =============================================================================

    c_err_periodo_cerrado     constant pls_integer := -20106;
    c_err_periodo_no_existe   constant pls_integer := -20107;

    function es_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) return boolean;

    procedure validar_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    );

end erp_gen_periodo_reg;
/
