create or replace package body adm_usuario_ctr
as

    procedure P_INSERTAR (
        I_USERNAME              in  varchar2,
        I_EMAIL                 in  varchar2,
        I_NOMBRES               in  varchar2,
        I_APELLIDOS             in  varchar2 default null,
        I_TIPO_AUTENTICACION    in  varchar2 default 'LOCAL',
        I_PASSWORD              in  varchar2 default null,
        I_EMPRESA_ID_DEFECTO    in  number   default null,
        O_USUARIO_ID            out number
    ) is
        V_SALT  raw(32);
        V_HASH  raw(64);
    begin
        if I_TIPO_AUTENTICACION = 'LOCAL' then
            adm_seguridad_reg.P_VALIDAR_POLITICA_PASSWORD(I_PASSWORD);
            V_SALT := adm_seguridad_reg.F_GENERAR_SALT;
            V_HASH := adm_seguridad_reg.F_HASH_PASSWORD(I_PASSWORD, V_SALT);
        end if;

        insert into adm_seg_usuario (
            username, email, nombres, apellidos, tipo_autenticacion,
            password_hash, password_salt, debe_cambiar_password, empresa_id_defecto)
        values (
            upper(trim(I_USERNAME)), lower(trim(I_EMAIL)), I_NOMBRES, I_APELLIDOS, I_TIPO_AUTENTICACION,
            V_HASH, V_SALT, case when I_TIPO_AUTENTICACION = 'LOCAL' then 'S' else 'N' end, I_EMPRESA_ID_DEFECTO)
        returning usuario_id into O_USUARIO_ID;
    end P_INSERTAR;

    procedure P_ACTUALIZAR (
        I_USUARIO_ID            in number,
        I_EMAIL                 in varchar2,
        I_NOMBRES               in varchar2,
        I_APELLIDOS             in varchar2,
        I_EMPRESA_ID_DEFECTO    in number,
        I_ESTADO                in varchar2
    ) is
    begin
        update adm_seg_usuario
           set email              = lower(trim(I_EMAIL)),
               nombres            = I_NOMBRES,
               apellidos          = I_APELLIDOS,
               empresa_id_defecto = I_EMPRESA_ID_DEFECTO,
               estado             = I_ESTADO
         where usuario_id = I_USUARIO_ID;

        if sql%rowcount = 0 then
            raise_application_error(-20020, 'Usuario ' || I_USUARIO_ID || ' no existe.');
        end if;
    end P_ACTUALIZAR;

    procedure P_CAMBIAR_PASSWORD (
        I_USUARIO_ID        in number,
        I_PASSWORD_NUEVO    in varchar2,
        I_DEBE_CAMBIAR      in varchar2 default 'S'
    ) is
        V_SALT  raw(32);
    begin
        adm_seguridad_reg.P_VALIDAR_POLITICA_PASSWORD(I_PASSWORD_NUEVO);
        V_SALT := adm_seguridad_reg.F_GENERAR_SALT;

        update adm_seg_usuario
           set password_salt         = V_SALT,
               password_hash         = adm_seguridad_reg.F_HASH_PASSWORD(I_PASSWORD_NUEVO, V_SALT),
               debe_cambiar_password = I_DEBE_CAMBIAR,
               fecha_cambio_password = systimestamp,
               intentos_fallidos     = 0
         where usuario_id = I_USUARIO_ID
           and tipo_autenticacion = 'LOCAL';

        if sql%rowcount = 0 then
            raise_application_error(-20021, 'Usuario ' || I_USUARIO_ID || ' no existe o no usa autenticación local.');
        end if;
    end P_CAMBIAR_PASSWORD;

    procedure P_DESBLOQUEAR (
        I_USUARIO_ID  in number
    ) is
    begin
        update adm_seg_usuario
           set estado            = 'A',
               intentos_fallidos = 0
         where usuario_id = I_USUARIO_ID
           and estado     = 'B';
    end P_DESBLOQUEAR;

    procedure P_ASIGNAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null,
        I_FECHA_DESDE   in date   default trunc(sysdate),
        I_FECHA_HASTA   in date   default null
    ) is
    begin
        merge into adm_seg_usuario_rol t
        using (select I_USUARIO_ID usuario_id, I_ROL_ID rol_id, I_EMPRESA_ID empresa_id from dual) s
           on (    t.usuario_id = s.usuario_id
               and t.rol_id     = s.rol_id
               and decode(t.empresa_id, s.empresa_id, 1, 0) = 1)
         when matched then
            update set t.fecha_desde = I_FECHA_DESDE,
                       t.fecha_hasta = I_FECHA_HASTA
         when not matched then
            insert (usuario_id, rol_id, empresa_id, fecha_desde, fecha_hasta)
            values (s.usuario_id, s.rol_id, s.empresa_id, I_FECHA_DESDE, I_FECHA_HASTA);
    end P_ASIGNAR_ROL;

    procedure P_QUITAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null
    ) is
    begin
        delete from adm_seg_usuario_rol
         where usuario_id = I_USUARIO_ID
           and rol_id     = I_ROL_ID
           and decode(empresa_id, I_EMPRESA_ID, 1, 0) = 1;
    end P_QUITAR_ROL;

end adm_usuario_ctr;
/
