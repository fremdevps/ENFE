create or replace package erp_doc_fe_documento_ctr
    authid definer
    accessible by (package erp_doc_fe_cola_reg, package erp_doc_fe_cola_api, package erp_doc_fe_documento_api)
as
-- =============================================================================
-- Paquete : erp_doc_fe_documento_ctr   (capa ctr)
-- Tabla   : erp_doc_fe_documento
-- =============================================================================

    procedure insertar (
        i_registro         in  erp_doc_fe_documento%rowtype,
        o_fe_documento_id  out erp_doc_fe_documento.fe_documento_id%type
    );

    -- Registro vacío (fe_documento_id null) si no existe.
    function obtener (
        i_fe_documento_id  in erp_doc_fe_documento.fe_documento_id%type
    ) return erp_doc_fe_documento%rowtype;

    -- select … for update (espera a que se libere la fila).
    function bloquear (
        i_fe_documento_id  in erp_doc_fe_documento.fe_documento_id%type
    ) return erp_doc_fe_documento%rowtype;

    -- Toma de la cola con select … for update skip locked: bloquea y devuelve hasta
    -- i_cantidad documentos en alguno de los dos estados y con proximo_intento vencido,
    -- saltando los que otra sesión ya tiene bloqueados (dos consumidores nunca toman el
    -- mismo documento). Orden: primero los que vencen antes.
    function bloquear_pendientes (
        i_empresa_id  in erp_doc_fe_documento.empresa_id%type,
        i_tipo_de     in erp_doc_fe_documento.tipo_de%type,
        i_cantidad    in pls_integer,
        i_estado_1    in erp_doc_fe_documento.estado_envio%type,
        i_estado_2    in erp_doc_fe_documento.estado_envio%type
    ) return sys.odcinumberlist;

    -- Actualiza las columnas del ciclo de vida (estados, respuesta, reintentos, lote).
    procedure actualizar_ciclo (
        i_registro  in erp_doc_fe_documento%rowtype
    );

end erp_doc_fe_documento_ctr;
/
