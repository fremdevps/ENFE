create or replace package body erp_doc_fe_cdc_utl
as

    -- Reemplaza cada letra por su código ASCII (los dígitos quedan igual).
    function convertir_letras (
        i_texto  in varchar2
    ) return varchar2 is
        v_texto     varchar2(200) := upper(trim(i_texto));
        v_salida    varchar2(600);
        v_caracter  varchar2(1 char);
    begin
        for i in 1 .. coalesce(length(v_texto), 0) loop
            v_caracter := substr(v_texto, i, 1);
            v_salida   := v_salida || case when v_caracter between '0' and '9'
                                           then v_caracter
                                           else to_char(ascii(v_caracter)) end;
        end loop;
        return v_salida;
    end convertir_letras;

    function calcular_dv (
        i_base  in varchar2
    ) return varchar2 is
        c_factor_max  constant pls_integer := 11;
        v_digitos     varchar2(600) := convertir_letras(i_texto => i_base);
        v_total       pls_integer := 0;
        v_factor      pls_integer := 2;
        v_resto       pls_integer;
    begin
        if v_digitos is null then
            return null;
        end if;
        for i in reverse 1 .. length(v_digitos) loop
            if v_factor > c_factor_max then
                v_factor := 2;
            end if;
            v_total  := v_total + to_number(substr(v_digitos, i, 1)) * v_factor;
            v_factor := v_factor + 1;
        end loop;
        v_resto := mod(v_total, 11);
        return case when v_resto > 1 then to_char(11 - v_resto) else '0' end;
    end calcular_dv;

    function generar_codigo_seguridad (
        i_numero_documento  in number default null
    ) return varchar2 is
        v_codigo  number;
    begin
        loop
            -- generador criptográfico de la base; 1 .. 999999999
            v_codigo := mod(dbms_crypto.randomnumber, 999999999) + 1;
            exit when i_numero_documento is null or v_codigo <> i_numero_documento;
        end loop;
        return lpad(to_char(v_codigo), 9, '0');
    end generar_codigo_seguridad;

    function generar_cdc (
        i_tipo_de             in number,
        i_ruc                 in varchar2,
        i_dv_ruc              in varchar2,
        i_establecimiento     in varchar2,
        i_punto_expedicion    in varchar2,
        i_numero              in number,
        i_tipo_contribuyente  in number,
        i_fecha_emision       in date,
        i_tipo_emision        in number,
        i_codigo_seguridad    in varchar2
    ) return varchar2 is
        v_ruc   varchar2(60) := convertir_letras(i_texto => i_ruc);
        v_base  varchar2(60);

        procedure validar (i_condicion in boolean, i_mensaje in varchar2) is
        begin
            if i_condicion is null or not i_condicion then
                raise_application_error(c_err_dato_invalido, 'No se puede generar el código de control: ' || i_mensaje);
            end if;
        end validar;
    begin
        validar(i_tipo_de between 1 and 99 and i_tipo_de = trunc(i_tipo_de), 'el tipo de documento electrónico no es válido.');
        validar(length(v_ruc) between 1 and 8, 'el RUC del emisor debe tener hasta 8 dígitos.');
        validar(regexp_like(i_dv_ruc, '^[0-9]$'), 'el dígito verificador del RUC debe ser un dígito.');
        validar(regexp_like(i_establecimiento, '^[0-9]{3}$'), 'el establecimiento debe tener 3 dígitos.');
        validar(regexp_like(i_punto_expedicion, '^[0-9]{3}$'), 'el punto de expedición debe tener 3 dígitos.');
        validar(i_numero between 1 and 9999999 and i_numero = trunc(i_numero), 'el número debe estar entre 1 y 9999999.');
        validar(i_tipo_contribuyente in (1, 2), 'el tipo de contribuyente debe ser 1 (física) o 2 (jurídica).');
        validar(i_fecha_emision is not null, 'falta la fecha de emisión.');
        validar(i_tipo_emision in (1, 2), 'el tipo de emisión debe ser 1 (normal) o 2 (contingencia).');
        validar(regexp_like(i_codigo_seguridad, '^[0-9]{9}$') and i_codigo_seguridad <> '000000000',
                'el código de seguridad debe tener 9 dígitos.');

        v_base := lpad(to_char(i_tipo_de), 2, '0')
                  || lpad(v_ruc, 8, '0')
                  || i_dv_ruc
                  || i_establecimiento
                  || i_punto_expedicion
                  || lpad(to_char(i_numero), 7, '0')
                  || to_char(i_tipo_contribuyente)
                  || to_char(i_fecha_emision, 'YYYYMMDD')
                  || to_char(i_tipo_emision)
                  || i_codigo_seguridad;
        return v_base || calcular_dv(i_base => v_base);
    end generar_cdc;

    function es_valido_sn (
        i_cdc  in varchar2
    ) return varchar2 is
    begin
        if i_cdc is null or not regexp_like(i_cdc, '^[0-9]{44}$') then
            return 'N';
        end if;
        return case when substr(i_cdc, 44, 1) = calcular_dv(i_base => substr(i_cdc, 1, 43)) then 'S' else 'N' end;
    end es_valido_sn;

    function formatear_cdc (
        i_cdc  in varchar2
    ) return varchar2 is
    begin
        return trim(regexp_replace(i_cdc, '(.{4})', '\1 '));
    end formatear_cdc;

end erp_doc_fe_cdc_utl;
/
