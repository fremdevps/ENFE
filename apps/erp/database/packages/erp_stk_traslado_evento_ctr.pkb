create or replace package body erp_stk_traslado_evento_ctr
as

    procedure insertar (
        i_evento  in  erp_stk_traslado_evento%rowtype,
        o_traslado_evento_id  out erp_stk_traslado_evento.traslado_evento_id%type
    ) is
    begin
        insert into erp_stk_traslado_evento values i_evento
        returning traslado_evento_id into o_traslado_evento_id;
    end insertar;

end erp_stk_traslado_evento_ctr;
/
