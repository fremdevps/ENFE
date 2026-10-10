create or replace package body erp_gen_empresa_func_ctr
as

    procedure insertar (
        i_empresa_id        in erp_gen_empresa_func.empresa_id%type,
        i_funcionalidad_id  in erp_gen_empresa_func.funcionalidad_id%type
    ) is
    begin
        merge into erp_gen_empresa_func t
        using (select i_empresa_id empresa_id, i_funcionalidad_id funcionalidad_id from dual) s
           on (t.empresa_id = s.empresa_id and t.funcionalidad_id = s.funcionalidad_id)
         when matched then
            update set t.estado = 'A'
         when not matched then
            insert (empresa_id, funcionalidad_id, estado)
            values (s.empresa_id, s.funcionalidad_id, 'A');
    end insertar;

end erp_gen_empresa_func_ctr;
/
