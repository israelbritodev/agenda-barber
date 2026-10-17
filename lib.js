// LIB: funções compartilhadas pelas 3 páginas. Mudou algo "geral"? Mude aqui, uma vez só.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { SUPABASE_URL, SUPABASE_KEY } from './config.js';

// Cliente Supabase único (evita criar várias conexões).
export const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

// Data local em AAAA-MM-DD (o locale 'sv' dá esse formato; toISOString erraria por fuso horário).
export const iso = (d) => d.toLocaleDateString('sv');

// Escapa HTML para que texto digitado (ex.: legenda) não injete código na página (segurança).
export const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// Carrega a tabela settings e transforma em objeto {chave: valor}. Todas as páginas usam isso.
export async function loadSettings() {
  const { data } = await sb.from('settings').select();
  return Object.fromEntries((data || []).map((r) => [r.key, r.value]));
}

// Aplica as configurações na página SEM código específico por página:
//  data-text="chave"  -> preenche o texto do elemento
//  data-bg="chave"    -> usa a imagem como fundo
//  data-link="chave"  -> define o href (data-prefix="https://wa.me/" para montar o link)
// Elemento com valor vazio é escondido; assim o barbeiro "remove" um bloco apagando o campo.
export function applySettings(s) {
  const root = document.documentElement.style;
  if (s.color_accent) root.setProperty('--ac', s.color_accent);   // cor de destaque
  if (s.color_bg) root.setProperty('--bg', s.color_bg);           // cor de fundo
  if (s.color_text) root.setProperty('--tx', s.color_text);       // cor do texto
  if (s.title) document.title = s.title;                          // título da aba do navegador
  document.querySelectorAll('[data-text]').forEach((el) => {
    const v = s[el.dataset.text] || ''; el.textContent = v; el.hidden = !v;
  });
  document.querySelectorAll('[data-bg]').forEach((el) => {
    const v = s[el.dataset.bg]; if (v) el.style.backgroundImage = `url(${v})`;
  });
  document.querySelectorAll('[data-link]').forEach((el) => {
    const v = s[el.dataset.link] || '';
    // WhatsApp: mantém só números; demais campos usam o valor como veio.
    const clean = el.dataset.prefix?.includes('wa.me') ? v.replace(/\D/g, '') : v.replace(/^@/, '');
    el.href = (el.dataset.prefix || '') + clean; el.hidden = !v;
  });
}
