create or replace package erp_gen_persona_ctr
    authid definer
    accessible by (package erp_gen_persona_api)
as
-- =============================================================================
-- Paquete : erp_gen_persona_ctr   (capa ctr)
-- Tabla   : erp_gen_persona
-- =============================================================================

    procedure insertar (
        i_persona  in  erp_gen_persona%rowtype,
        o_persona_id out erp_gen_persona.persona_id%type
    );

    procedure actualizar (
        i_persona  in erp_gen_persona%rowtype
    );

end erp_gen_persona_ctr;
/
