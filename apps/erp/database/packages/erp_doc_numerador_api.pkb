create or replace package body erp_doc_numerador_api
as

    function obtener_numerador (
        i_punto_expedicion_id  in number,
        i_tipo_documento_id    in number,
        i_fecha                in date default current_date
    ) return number is
    begin
        return erp_doc_numerador_reg.obtener_numerador(i_punto_expedicion_id => i_punto_expedicion_id,
                                                       i_tipo_documento_id   => i_tipo_documento_id,
                                                       i_fecha               => coalesce(i_fecha, current_date));
    end obtener_numerador;

    procedure tomar_siguiente (
        i_numerador_id       in  number,
        i_fecha              in  date     default current_date,
        i_usuario            in  varchar2 default null,
        i_espera_segundos    in  number   default null,
        o_numero             out number,
        o_numero_formateado  out varchar2
    ) is
    begin
        erp_doc_numerador_reg.tomar_siguiente(i_numerador_id      => i_numerador_id,
                                              i_fecha             => i_fecha,
                                              i_usuario           => i_usuario,
                                              i_espera_segundos   => i_espera_segundos,
                                              o_numero            => o_numero,
                                              o_numero_formateado => o_numero_formateado);
    end tomar_siguiente;

    function formatear_numero (
        i_establecimiento   in varchar2,
        i_punto_expedicion  in varchar2,
        i_numero            in number
    ) return varchar2 is
    begin
        return erp_doc_numerador_reg.formatear_numero(i_establecimiento  => i_establecimiento,
                                                      i_punto_expedicion => i_punto_expedicion,
                                                      i_numero           => i_numero);
    end formatear_numero;

    procedure validar_formato (
        i_numero_formateado  in  varchar2,
        o_establecimiento    out varchar2,
        o_punto_expedicion   out varchar2,
        o_numero             out number
    ) is
    begin
        erp_doc_numerador_reg.validar_formato(i_numero_formateado => i_numero_formateado,
                                              o_establecimiento   => o_establecimiento,
                                              o_punto_expedicion  => o_punto_expedicion,
                                              o_numero            => o_numero);
    end validar_formato;

    function es_formato_valido_sn (
        i_numero_formateado  in varchar2
    ) return varchar2 is
        v_establecimiento  varchar2(3);
        v_punto            varchar2(3);
        v_numero           number;
    begin
        validar_formato(i_numero_formateado => i_numero_formateado,
                        o_establecimiento   => v_establecimiento,
                        o_punto_expedicion  => v_punto,
                        o_numero            => v_numero);
        return 'S';
    exception
        when others then
            if sqlcode = erp_doc_numerador_reg.c_err_formato_numero then
                return 'N';
            end if;
            raise;
    end es_formato_valido_sn;

    function obtener_aviso (
        i_numerador_id  in number,
        i_fecha         in date default current_date
    ) return varchar2 is
    begin
        return erp_doc_numerador_reg.obtener_aviso(i_numerador_id => i_numerador_id, i_fecha => i_fecha);
    end obtener_aviso;

    procedure inutilizar (
        i_numerador_id           in  number,
        i_numero_desde           in  number,
        i_numero_hasta           in  number   default null,
        i_tipo                   in  varchar2,
        i_motivo                 in  varchar2,
        i_motivo_id              in  number   default null,
        i_fecha                  in  date     default current_date,
        o_numero_inutilizado_id  out number
    ) is
        v_usuario    varchar2(255) := sys_context('APEX$SESSION', 'APP_USER');
        v_empresa_id number;
    begin
        if v_usuario is not null then
            select max(empresa_id) into v_empresa_id from erp_doc_numerador where numerador_id = i_numerador_id;
            if not adm_seg_seguridad_reg.tiene_permiso(i_username       => v_usuario,
                                                       i_permiso_codigo => c_permiso_inutilizar,
                                                       i_empresa_id     => v_empresa_id) then
                raise_application_error(c_err_sin_permiso, 'No tiene permiso para anular o inutilizar números de comprobantes.');
            end if;
        end if;
        erp_doc_numerador_reg.inutilizar(i_numerador_id          => i_numerador_id,
                                         i_numero_desde          => i_numero_desde,
                                         i_numero_hasta          => i_numero_hasta,
                                         i_tipo                  => i_tipo,
                                         i_motivo_id             => i_motivo_id,
                                         i_motivo                => i_motivo,
                                         i_fecha                 => i_fecha,
                                         o_numero_inutilizado_id => o_numero_inutilizado_id);
    end inutilizar;

end erp_doc_numerador_api;
/
