create or replace package body erp_stk_movimiento_item_ctr
as

    procedure insertar (
        i_items  in t_item_tab
    ) is
    begin
        -- Los campos nulos del registro (PK, auditoría) toman su valor por defecto
        -- (identity y columnas "default on null").
        forall i in 1 .. i_items.count
            insert into erp_stk_movimiento_item values i_items(i);
    end insertar;

end erp_stk_movimiento_item_ctr;
/
