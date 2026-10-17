-- Rode APENAS se você já executou o supabase.sql antes (não apaga nada).

-- is_barber(): diz se um e-mail está cadastrado como barbeiro. O login usa isso para decidir entre
-- "pedir senha" e "enviar para o WhatsApp de contato". Devolve só true/false (não expõe a lista).
create or replace function is_barber(p_email text) returns bool language sql security definer stable as
$$ select exists(select 1 from admins where lower(email) = lower(p_email)) $$;
-- is_admin() refeita ignorando maiúsculas/minúsculas, para o e-mail do cadastro sempre casar com o do login.
create or replace function is_admin() returns bool language sql security definer stable as
$$ select exists(select 1 from admins where lower(email) = lower(auth.jwt()->>'email')) $$;
