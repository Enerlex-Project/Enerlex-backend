drop extension if exists "pg_net";


  create table "public"."alertas" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "dispositivo_id" uuid,
    "tipo" text not null,
    "mensaje" text not null,
    "activa" boolean default true,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."alertas" enable row level security;


  create table "public"."consumo_historico" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "mes" text not null,
    "anio" integer not null,
    "kwh" double precision not null default 0,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."consumo_historico" enable row level security;


  create table "public"."dispositivos" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "nombre" text not null,
    "icono" text default 'device_unknown'::text,
    "watts" integer not null default 0,
    "kwh_hoy" double precision default 0,
    "encendido" boolean default false,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."dispositivos" enable row level security;


  create table "public"."perfiles" (
    "id" uuid not null,
    "nombre" text not null,
    "correo" text not null,
    "plan" text default 'Hogar Premium'::text,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."perfiles" enable row level security;

CREATE UNIQUE INDEX alertas_pkey ON public.alertas USING btree (id);

CREATE UNIQUE INDEX consumo_historico_pkey ON public.consumo_historico USING btree (id);

CREATE UNIQUE INDEX dispositivos_pkey ON public.dispositivos USING btree (id);

CREATE UNIQUE INDEX perfiles_pkey ON public.perfiles USING btree (id);

alter table "public"."alertas" add constraint "alertas_pkey" PRIMARY KEY using index "alertas_pkey";

alter table "public"."consumo_historico" add constraint "consumo_historico_pkey" PRIMARY KEY using index "consumo_historico_pkey";

alter table "public"."dispositivos" add constraint "dispositivos_pkey" PRIMARY KEY using index "dispositivos_pkey";

alter table "public"."perfiles" add constraint "perfiles_pkey" PRIMARY KEY using index "perfiles_pkey";

alter table "public"."alertas" add constraint "alertas_dispositivo_id_fkey" FOREIGN KEY (dispositivo_id) REFERENCES public.dispositivos(id) ON DELETE CASCADE not valid;

alter table "public"."alertas" validate constraint "alertas_dispositivo_id_fkey";

alter table "public"."alertas" add constraint "alertas_tipo_check" CHECK ((tipo = ANY (ARRAY['elevado'::text, 'excesivo'::text, 'global'::text]))) not valid;

alter table "public"."alertas" validate constraint "alertas_tipo_check";

alter table "public"."alertas" add constraint "alertas_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.perfiles(id) ON DELETE CASCADE not valid;

alter table "public"."alertas" validate constraint "alertas_user_id_fkey";

alter table "public"."consumo_historico" add constraint "consumo_historico_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.perfiles(id) ON DELETE CASCADE not valid;

alter table "public"."consumo_historico" validate constraint "consumo_historico_user_id_fkey";

alter table "public"."dispositivos" add constraint "dispositivos_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.perfiles(id) ON DELETE CASCADE not valid;

alter table "public"."dispositivos" validate constraint "dispositivos_user_id_fkey";

alter table "public"."perfiles" add constraint "perfiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."perfiles" validate constraint "perfiles_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_perfil()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.dispositivos (user_id, nombre, icono, watts, kwh_hoy, encendido)
  values
    (new.id, 'TV Sala',            'tv_outlined',                    150,  1.2,  true),
    (new.id, 'Nevera',             'kitchen_outlined',               350,  1.2,  true),
    (new.id, 'PC Oficina',         'computer_outlined',              200,  1.6,  true),
    (new.id, 'Lámpara Cuarto',     'lightbulb_outline',              60,   0.1,  true),
    (new.id, 'Microondas',         'microwave_outlined',             1200, 9.6,  false),
    (new.id, 'Ventilador',         'wind_power_outlined',            70,   0.56, true),
    (new.id, 'Lavadora',           'local_laundry_service_outlined', 500,  4.0,  false),
    (new.id, 'Aire Acondicionado', 'ac_unit',                        1500, 12.0, false),
    (new.id, 'Secadora',           'dry_outlined',                   2500, 20.0, false);
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  insert into public.perfiles (id, nombre, correo)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1)),
    new.email
  );
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

grant references on table "public"."alertas" to "anon";

grant trigger on table "public"."alertas" to "anon";

grant truncate on table "public"."alertas" to "anon";

grant references on table "public"."alertas" to "authenticated";

grant trigger on table "public"."alertas" to "authenticated";

grant truncate on table "public"."alertas" to "authenticated";

grant references on table "public"."alertas" to "service_role";

grant trigger on table "public"."alertas" to "service_role";

grant truncate on table "public"."alertas" to "service_role";

grant references on table "public"."consumo_historico" to "anon";

grant trigger on table "public"."consumo_historico" to "anon";

grant truncate on table "public"."consumo_historico" to "anon";

grant references on table "public"."consumo_historico" to "authenticated";

grant trigger on table "public"."consumo_historico" to "authenticated";

grant truncate on table "public"."consumo_historico" to "authenticated";

grant references on table "public"."consumo_historico" to "service_role";

grant trigger on table "public"."consumo_historico" to "service_role";

grant truncate on table "public"."consumo_historico" to "service_role";

grant references on table "public"."dispositivos" to "anon";

grant trigger on table "public"."dispositivos" to "anon";

grant truncate on table "public"."dispositivos" to "anon";

grant references on table "public"."dispositivos" to "authenticated";

grant trigger on table "public"."dispositivos" to "authenticated";

grant truncate on table "public"."dispositivos" to "authenticated";

grant references on table "public"."dispositivos" to "service_role";

grant trigger on table "public"."dispositivos" to "service_role";

grant truncate on table "public"."dispositivos" to "service_role";

grant references on table "public"."perfiles" to "anon";

grant trigger on table "public"."perfiles" to "anon";

grant truncate on table "public"."perfiles" to "anon";

grant references on table "public"."perfiles" to "authenticated";

grant trigger on table "public"."perfiles" to "authenticated";

grant truncate on table "public"."perfiles" to "authenticated";

grant references on table "public"."perfiles" to "service_role";

grant trigger on table "public"."perfiles" to "service_role";

grant truncate on table "public"."perfiles" to "service_role";


  create policy "alertas_propias"
  on "public"."alertas"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "consumo_propio"
  on "public"."consumo_historico"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "dispositivos_propios"
  on "public"."dispositivos"
  as permissive
  for all
  to public
using ((auth.uid() = user_id));



  create policy "perfil_propio"
  on "public"."perfiles"
  as permissive
  for all
  to public
using ((auth.uid() = id));


CREATE TRIGGER on_perfil_created AFTER INSERT ON public.perfiles FOR EACH ROW EXECUTE FUNCTION public.handle_new_perfil();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


