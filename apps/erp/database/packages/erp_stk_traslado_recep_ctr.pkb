create or replace package body erp_stk_traslado_recep_ctr
as

    procedure insertar (
        i_recepcion  in  erp_stk_traslado_recep%rowtype,
        o_traslado_recep_id  out erp_stk_traslado_recep.traslado_recep_id%type
    ) is
    begin
        insert into erp_stk_traslado_recep values i_recepcion
        returning traslado_recep_id into o_traslado_recep_id;
    end insertar;

end erp_stk_traslado_recep_ctr;
/
