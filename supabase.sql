-- =====================================================================
-- BANCO DA BARBEARIA v3 (cole tudo no Supabase > SQL Editor > Run)
-- ATENÇÃO: o início APAGA as tabelas antigas. Troque o e-mail do admin na linha indicada.
-- =====================================================================
drop policy if exists "ler" on storage.objects;
drop policy if exists "subir" on storage.objects;
drop policy if exists "apagar" on storage.objects;
drop table if exists settings, admins, works, services, availability, days_off, bookings, customers cascade;
drop function if exists is_admin(), is_barber(text), taken_slots(date), on_booking();

-- SETTINGS: textos/imagens/cores do site (chave -> valor). Campo novo no site = chave nova, sem mexer no banco.
create table settings(key text primary key, value text);
insert into settings(key,value) values
 ('title','Minha Barbearia'),('subtitle','Estilo e precisão'),('about_title','Sobre'),
 ('about','Conte aqui a sua história.'),('gallery_title','Nosso trabalho'),('book_button','Agendar horário'),
 ('whatsapp',''),('instagram',''),('address',''),('footer',''),('hero_url',''),
 ('color_accent','#c9a45c'),('color_bg','#0e0d0c'),('color_text','#f2ece0'),
 ('slot_minutes','20'),('days_ahead','14'); -- slot_minutes = intervalo entre horários oferecidos

-- ADMINS: e-mails autorizados a editar o site.
create table admins(email text primary key);
insert into admins values('jrisraelbrito@gmail.com'); -- << TROQUE pelo e-mail do barbeiro

-- WORKS: fotos/vídeos da galeria.
create table works(id uuid primary key default gen_random_uuid(), url text not null, type text default 'image', caption text, created_at timestamptz default now());

-- SERVICES: serviços com preço e DURAÇÃO (é a duração que bloqueia o horário na agenda).
create table services(id uuid primary key default gen_random_uuid(), name text not null, price numeric, duration_min int default 40, active bool default true);

-- AVAILABILITY: horário de funcionamento por dia da semana (0=Dom..6=Sáb). Sem registro = fechado.
create table availability(weekday int primary key check(weekday between 0 and 6), start_time time not null, end_time time not null);

-- DAYS_OFF: folgas/feriados em datas específicas.
create table days_off(date date primary key, reason text);

-- CUSTOMERS (CRM): um registro por telefone. Preenchido AUTOMATICAMENTE a cada agendamento (trigger abaixo).
create table customers(phone text primary key, name text not null, notes text, created_at timestamptz default now());

-- BOOKINGS: agendamentos. duration_min é copiado do serviço no momento da reserva (histórico não muda se o serviço mudar).
create table bookings(id uuid primary key default gen_random_uuid(), name text not null, phone text not null, service text,
  "date" date not null, "time" time not null, duration_min int default 40, status text default 'agendado', created_at timestamptz default now());

-- PROTEÇÃO CONTRA SOBREPOSIÇÃO (no banco, vale mesmo se alguém burlar o site):
-- dois agendamentos ativos não podem ter intervalos [início, início+duração) que se cruzem.
-- Ex.: corte de 40 min às 09:00 => nada entre 09:00 e 09:40.
alter table bookings add constraint no_overlap exclude using gist
  ((tsrange("date" + "time", "date" + "time" + make_interval(mins => duration_min))) with &&) where (status <> 'cancelado');

-- on_booking(): roda ANTES de gravar cada agendamento: (1) guarda só os números do telefone,
-- (2) copia a duração do serviço escolhido, (3) cria/atualiza o cliente no CRM.
create function on_booking() returns trigger language plpgsql security definer as $$
begin
  new.phone := regexp_replace(new.phone, '\D', '', 'g');
  new.duration_min := coalesce((select s.duration_min from services s where s.name = new.service limit 1),
                               (select value::int from settings where key = 'slot_minutes'), 40);
  insert into customers(phone, name) values (new.phone, new.name)
    on conflict (phone) do update set name = excluded.name;
  return new;
end $$;
create trigger trg_booking before insert on bookings for each row execute function on_booking();

-- is_admin(): quem está logado é admin? (ignora maiúsculas). Base de todas as regras de escrita.
create function is_admin() returns bool language sql security definer stable as
$$ select exists(select 1 from admins where lower(email) = lower(auth.jwt()->>'email')) $$;
-- is_barber(): o e-mail digitado no login está cadastrado? (decide entre pedir senha ou abrir o WhatsApp de contato)
create function is_barber(p_email text) returns bool language sql security definer stable as
$$ select exists(select 1 from admins where lower(email) = lower(p_email)) $$;
-- taken_slots(): início e duração dos horários ocupados de um dia (sem expor nome/telefone de ninguém).
create function taken_slots(d date) returns table(start_time time, dur int) language sql security definer as
$$ select "time", duration_min from bookings where "date" = d and status <> 'cancelado' $$;

-- RLS: sem policy ninguém acessa. Conteúdo: todos leem, só admin escreve.
alter table settings enable row level security; alter table admins enable row level security;
alter table works enable row level security;    alter table services enable row level security;
alter table availability enable row level security; alter table days_off enable row level security;
alter table bookings enable row level security; alter table customers enable row level security;
create policy r on settings for select using(true);     create policy w on settings for all using(is_admin()) with check(is_admin());
create policy r on works for select using(true);        create policy w on works for all using(is_admin()) with check(is_admin());
create policy r on services for select using(true);     create policy w on services for all using(is_admin()) with check(is_admin());
create policy r on availability for select using(true); create policy w on availability for all using(is_admin()) with check(is_admin());
create policy r on days_off for select using(true);     create policy w on days_off for all using(is_admin()) with check(is_admin());
create policy ins on bookings for insert with check(status='agendado');     -- cliente só cria
create policy adm on bookings for all using(is_admin()) with check(is_admin());
create policy adm on customers for all using(is_admin()) with check(is_admin()); -- CRM é só do barbeiro

-- STORAGE: bucket público "media"; só admin envia/apaga.
insert into storage.buckets(id,name,public) values('media','media',true) on conflict do nothing;
create policy "ler" on storage.objects for select using(bucket_id='media');
create policy "subir" on storage.objects for insert with check(bucket_id='media' and is_admin());
create policy "apagar" on storage.objects for delete using(bucket_id='media' and is_admin());
