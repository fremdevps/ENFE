-- =============================================================================
-- OPCIONAL: particiona adm_aud_cambio por mes (intervalo sobre fecha).
-- Conviene cuando el historial crece mucho: la purga y las consultas por fecha
-- trabajan por partición. No lo ejecuta install.sql; el modelo no depende de él.
--   Autonomous Database : incluido.
--   On-premise          : requiere Enterprise Edition + opción Partitioning (12.2+).
-- En línea (online): no bloquea el uso de la tabla. Ejecutar una sola vez.
-- Nota: fecha es timestamp with local time zone, por eso el límite lleva zona.
-- =============================================================================
alter table adm_aud_cambio modify
    partition by range (fecha) interval (numtoyminterval(1, 'MONTH'))
    (partition p_inicial values less than (timestamp '2026-01-01 00:00:00 +00:00'))
    online
    update indexes (
        idx_adm_cam_tab_reg_fecha local,
        idx_adm_cam_fecha         local,
        idx_adm_cam_tab_padre     local
    );
