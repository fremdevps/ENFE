create or replace package erp_doc_numerador_ctr
    authid definer
    accessible by (package erp_doc_numerador_reg, package erp_doc_numerador_api)
as
-- =============================================================================
-- Paquete : erp_doc_numerador_ctr   (capa ctr)
-- Tabla   : erp_doc_numerador
-- =============================================================================

    -- La fila está bloqueada por otra transacción y venció la espera (ORA-30006).
    e_recurso_ocupado  exception;
    pragma exception_init(e_recurso_ocupado, -30006);

    -- Registro vacío (numerador_id null) si no existe.
    function obtener (
        i_numerador_id  in erp_doc_numerador.numerador_id%type
    ) return erp_doc_numerador%rowtype;

    -- select … for update: bloquea la fila hasta el fin de la transacción del llamador.
    -- Espera hasta i_espera_segundos; si no la consigue lanza e_recurso_ocupado.
    function bloquear (
        i_numerador_id     in erp_doc_numerador.numerador_id%type,
        i_espera_segundos  in pls_integer
    ) return erp_doc_numerador%rowtype;

    procedure actualizar_numero (
        i_numerador_id   in erp_doc_numerador.numerador_id%type,
        i_numero_actual  in erp_doc_numerador.numero_actual%type
    );

end erp_doc_numerador_ctr;
/
