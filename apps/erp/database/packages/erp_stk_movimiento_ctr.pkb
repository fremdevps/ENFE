create or replace package body erp_stk_movimiento_ctr
as

    procedure insertar (
        i_movimiento     in  erp_stk_movimiento%rowtype,
        o_movimiento_id  out erp_stk_movimiento.movimiento_id%type
    ) is
    begin
        insert into erp_stk_movimiento (
            empresa_id, tipo_movimiento_id, fecha_movimiento, origen_modulo, origen_tabla, origen_id,
            motivo, observacion, es_reverso, movimiento_id_reversado, estado, creado_por)
        values (
            i_movimiento.empresa_id, i_movimiento.tipo_movimiento_id, i_movimiento.fecha_movimiento,
            i_movimiento.origen_modulo, i_movimiento.origen_tabla, i_movimiento.origen_id,
            i_movimiento.motivo, i_movimiento.observacion, i_movimiento.es_reverso,
            i_movimiento.movimiento_id_reversado, i_movimiento.estado, i_movimiento.creado_por)
        returning movimiento_id into o_movimiento_id;
    end insertar;

    function bloquear (
        i_movimiento_id  in erp_stk_movimiento.movimiento_id%type
    ) return erp_stk_movimiento%rowtype is
        r_movimiento  erp_stk_movimiento%rowtype;
    begin
        select *
          into r_movimiento
          from erp_stk_movimiento
         where movimiento_id = i_movimiento_id
           for update;
        return r_movimiento;
    end bloquear;

    procedure actualizar_estado (
        i_movimiento_id  in erp_stk_movimiento.movimiento_id%type,
        i_estado         in erp_stk_movimiento.estado%type
    ) is
    begin
        update erp_stk_movimiento
           set estado = i_estado
         where movimiento_id = i_movimiento_id;
    end actualizar_estado;

end erp_stk_movimiento_ctr;
/
