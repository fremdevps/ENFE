create or replace package body erp_stk_traslado_recep_det_ctr
as

    procedure insertar (
        i_detalle  in  erp_stk_traslado_recep_det%rowtype,
        o_traslado_recep_det_id  out erp_stk_traslado_recep_det.traslado_recep_det_id%type
    ) is
    begin
        insert into erp_stk_traslado_recep_det values i_detalle
        returning traslado_recep_det_id into o_traslado_recep_det_id;
    end insertar;

    procedure actualizar (
        i_detalle  in erp_stk_traslado_recep_det%rowtype
    ) is
    begin
        update erp_stk_traslado_recep_det
           set row = i_detalle
         where traslado_recep_det_id = i_detalle.traslado_recep_det_id;
    end actualizar;

    function bloquear (
        i_traslado_recep_det_id  in erp_stk_traslado_recep_det.traslado_recep_det_id%type
    ) return erp_stk_traslado_recep_det%rowtype is
        r_detalle  erp_stk_traslado_recep_det%rowtype;
    begin
        select *
          into r_detalle
          from erp_stk_traslado_recep_det
         where traslado_recep_det_id = i_traslado_recep_det_id
           for update;
        return r_detalle;
    end bloquear;

end erp_stk_traslado_recep_det_ctr;
/
