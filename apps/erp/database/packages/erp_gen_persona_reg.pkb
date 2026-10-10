create or replace package body erp_gen_persona_reg
as

    function calcular_dv_ruc (
        i_numero  in varchar2
    ) return varchar2 is
        c_base_max  constant pls_integer := 11;
        v_numero    varchar2(100) := upper(trim(i_numero));
        v_digitos   varchar2(400);
        v_caracter  varchar2(1);
        v_total     pls_integer := 0;
        v_k         pls_integer := 2;
        v_resto     pls_integer;
    begin
        if v_numero is null then
            return null;
        end if;
        for i in 1 .. length(v_numero) loop
            v_caracter := substr(v_numero, i, 1);
            v_digitos  := v_digitos || case when v_caracter between '0' and '9'
                                            then v_caracter
                                            else to_char(ascii(v_caracter)) end;
        end loop;
        for i in reverse 1 .. length(v_digitos) loop
            if v_k > c_base_max then
                v_k := 2;
            end if;
            v_total := v_total + to_number(substr(v_digitos, i, 1)) * v_k;
            v_k     := v_k + 1;
        end loop;
        v_resto := mod(v_total, 11);
        return case when v_resto > 1 then to_char(11 - v_resto) else '0' end;
    end calcular_dv_ruc;

    procedure aplicar_formato_documento (
        io_nro_documento  in out nocopy varchar2,
        io_dv             in out nocopy varchar2
    ) is
    begin
        io_nro_documento := upper(replace(replace(trim(io_nro_documento), '.', ''), ' ', ''));
        io_dv            := trim(io_dv);
        if io_dv is null and instr(io_nro_documento, '-') > 0 then
            io_dv            := substr(io_nro_documento, instr(io_nro_documento, '-', -1) + 1);
            io_nro_documento := substr(io_nro_documento, 1, instr(io_nro_documento, '-', -1) - 1);
        end if;
    end aplicar_formato_documento;

    procedure validar_documento (
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type
    ) is
        r_tipo  erp_gen_tipo_doc_identidad%rowtype;
    begin
        begin
            select * into r_tipo
              from erp_gen_tipo_doc_identidad
             where tipo_doc_identidad_id = i_tipo_doc_identidad_id
               and estado = 'A';
        exception
            when no_data_found then
                raise_application_error(c_err_tipo_doc_invalido, 'El tipo de documento no existe o está inactivo.');
        end;

        if r_tipo.formato_regexp is not null
           and not regexp_like(i_nro_documento, r_tipo.formato_regexp) then
            raise_application_error(c_err_documento_formato,
                'El número de documento no tiene el formato esperado para ' || r_tipo.nombre || '.');
        end if;

        if r_tipo.tiene_dv = 'S' then
            if i_dv is null or i_dv <> calcular_dv_ruc(i_numero => i_nro_documento) then
                raise_application_error(c_err_dv_invalido,
                    'El dígito verificador no corresponde al número de ' || r_tipo.nombre || '.');
            end if;
        end if;
    end validar_documento;

end erp_gen_persona_reg;
/
