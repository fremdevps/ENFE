create or replace package body adm_gen_error_api
as

    c_msg_inesperado  constant varchar2(200) :=
        'Ocurrió un error inesperado. Informe al administrador el código de incidente ';

    function registrar_incidente (
        i_componente   in varchar2,
        i_mensaje      in varchar2,
        i_ora_sqlcode  in number,
        i_ora_sqlerrm  in varchar2,
        i_backtrace    in varchar2
    ) return number is
        v_error_id  adm_aud_error.error_id%type;
    begin
        adm_aud_error_ctr.insertar(
            i_apex_app_id     => to_number(sys_context('APEX$SESSION', 'APP_ID')),
            i_apex_pagina_id  => to_number(sys_context('APEX$SESSION', 'APP_PAGE_ID')),
            i_username        => coalesce(sys_context('APEX$SESSION', 'APP_USER'), user),
            i_componente      => i_componente,
            i_mensaje         => i_mensaje,
            i_ora_sqlcode     => i_ora_sqlcode,
            i_ora_sqlerrm     => i_ora_sqlerrm,
            i_error_backtrace => i_backtrace,
            o_error_id        => v_error_id);
        return v_error_id;
    end registrar_incidente;

    function manejar_error_apex (
        p_error  in apex_error.t_error
    ) return apex_error.t_error_result is
        r_resultado   apex_error.t_error_result;
        v_constraint  varchar2(128);
        v_mensaje     adm_gen_mensaje_error.mensaje%type;
        v_error_id    number;

        function componente return varchar2 is
        begin
            return p_error.component.type || ': ' || p_error.component.name;
        end componente;
    begin
        r_resultado := apex_error.init_error_result(p_error => p_error);

        if p_error.is_internal_error then
            -- Errores comunes de ejecución (sesión expirada, acceso denegado) se muestran tal cual
            if not p_error.is_common_runtime_error then
                v_error_id := registrar_incidente(
                    i_componente  => componente,
                    i_mensaje     => p_error.message,
                    i_ora_sqlcode => p_error.ora_sqlcode,
                    i_ora_sqlerrm => p_error.ora_sqlerrm,
                    i_backtrace   => p_error.error_backtrace);
                r_resultado.message         := c_msg_inesperado || v_error_id || '.';
                r_resultado.additional_info := null;
            end if;
        else
            r_resultado.display_location :=
                case when r_resultado.display_location = apex_error.c_on_error_page
                     then apex_error.c_inline_in_notification
                     else r_resultado.display_location
                end;

            if p_error.ora_sqlcode in (-1, -2091, -2290, -2291, -2292) then
                v_constraint := apex_error.extract_constraint_name(p_error => p_error);
                v_mensaje    := adm_gen_mensaje_error_ctr.obtener_mensaje(i_codigo => v_constraint);
                if v_mensaje is not null then
                    r_resultado.message := v_mensaje;
                else
                    v_error_id := registrar_incidente(
                        i_componente  => componente,
                        i_mensaje     => 'Constraint sin mensaje: ' || v_constraint,
                        i_ora_sqlcode => p_error.ora_sqlcode,
                        i_ora_sqlerrm => p_error.ora_sqlerrm,
                        i_backtrace   => p_error.error_backtrace);
                    r_resultado.message := 'Los datos no cumplen una regla de integridad (' ||
                                           lower(v_constraint) || '). Incidente ' || v_error_id || '.';
                end if;
            elsif p_error.ora_sqlcode between -20999 and -20000 then
                r_resultado.message := apex_error.get_first_ora_error_text(p_error => p_error);
            elsif p_error.ora_sqlcode is not null then
                v_error_id := registrar_incidente(
                    i_componente  => componente,
                    i_mensaje     => p_error.message,
                    i_ora_sqlcode => p_error.ora_sqlcode,
                    i_ora_sqlerrm => p_error.ora_sqlerrm,
                    i_backtrace   => p_error.error_backtrace);
                r_resultado.message := c_msg_inesperado || v_error_id || '.';
            end if;

            -- Asociar el error al item/columna que lo causó cuando APEX puede deducirlo
            if r_resultado.page_item_name is null and r_resultado.column_alias is null then
                apex_error.auto_set_associated_item(p_error => p_error, p_error_result => r_resultado);
            end if;
        end if;

        return r_resultado;
    end manejar_error_apex;

    function registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) return number is
    begin
        return registrar_incidente(
            i_componente  => i_componente,
            i_mensaje     => coalesce(i_mensaje, sqlerrm),
            i_ora_sqlcode => sqlcode,
            i_ora_sqlerrm => sqlerrm,
            i_backtrace   => dbms_utility.format_error_backtrace);
    end registrar;

    procedure registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) is
        v_error_id  number;
    begin
        v_error_id := registrar(i_componente => i_componente, i_mensaje => i_mensaje);
    end registrar;

end adm_gen_error_api;
/
