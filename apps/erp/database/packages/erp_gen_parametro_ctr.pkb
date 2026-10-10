create or replace package body erp_gen_parametro_ctr
as

    function obtener (
        i_codigo      in erp_gen_parametro.codigo%type,
        i_empresa_id  in erp_gen_parametro.empresa_id%type default null
    ) return erp_gen_parametro%rowtype is
        r_parametro  erp_gen_parametro%rowtype;
    begin
        select *
          into r_parametro
          from erp_gen_parametro
         where codigo = upper(i_codigo)
           and (empresa_id = i_empresa_id or empresa_id is null)
         order by empresa_id nulls last
         fetch first 1 row only;
        return r_parametro;
    exception
        when no_data_found then
            return r_parametro;
    end obtener;

end erp_gen_parametro_ctr;
/
