create or replace package body erp_gen_parametro_api
as

    function obtener_texto (
        i_codigo      in varchar2,
        i_empresa_id  in number   default null,
        i_defecto     in varchar2 default null
    ) return varchar2 is
        r_parametro  erp_gen_parametro%rowtype;
    begin
        r_parametro := erp_gen_parametro_ctr.obtener(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        return coalesce(r_parametro.valor, i_defecto);
    end obtener_texto;

    function obtener_numero (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in number default null
    ) return number is
        v_valor  erp_gen_parametro.valor%type;
    begin
        v_valor := obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        if v_valor is null then
            return i_defecto;
        end if;
        return to_number(v_valor, '99999999999999999999D9999999999', 'nls_numeric_characters=''.,''');
    end obtener_numero;

    function obtener_fecha (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in date   default null
    ) return date is
        v_valor  erp_gen_parametro.valor%type;
    begin
        v_valor := obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id);
        if v_valor is null then
            return i_defecto;
        end if;
        return to_date(v_valor, 'YYYY-MM-DD');
    end obtener_fecha;

    function obtener_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number      default null,
        i_defecto     in varchar2    default 'N'
    ) return varchar2 is
    begin
        return case upper(obtener_texto(i_codigo => i_codigo, i_empresa_id => i_empresa_id, i_defecto => i_defecto))
                   when 'S' then 'S'
                   else 'N'
               end;
    end obtener_sn;

end erp_gen_parametro_api;
/
