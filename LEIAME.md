# Mapa do projeto (para futuras edições)
- `supabase.sql`  → banco, regras de segurança e storage. Rode uma vez no Supabase.
- `config.js`     → URL e chave do Supabase (único lugar).
- `lib.js`        → funções compartilhadas (conexão, carregar/aplicar configurações).
- `style.css`     → visual; cores vêm do admin via variáveis CSS.
- `index.html`    → página principal (galeria + textos). Tudo vem do banco por data-text/data-bg/data-link.
- `agendar.html`  → fluxo do cliente: serviço → dia → horário → confirmar.
- `admin.html`    → painel. Para novo campo editável: 1 linha em FIELDS + data-text no HTML.

## Como crescer (escalabilidade)
- Novo campo de texto/imagem/cor: linha em FIELDS (admin.html) + `data-text="chave"` na página.
- Nova seção do admin: nova função renderXxx() + chamada em boot().
- Cadastro de clientes, histórico e cupons: usar Supabase Auth (já incluso) e criar tabelas
  `coupons` e `customer_coupons`; ligar bookings.user_id ao usuário logado. As regras RLS seguem o padrão do supabase.sql.

## v3 — novidades
- Duração por serviço (services.duration_min) bloqueia o intervalo na agenda; o banco recusa sobreposição (restrição no_overlap).
- CRM: tabela customers preenchida pelo trigger on_booking a cada agendamento.
- Admin: calendário por intensidade, busca/filtros, CRM, avisos (toast). Gravar no Supabase exige `await` (use saved()).
