# Central de Garantias

MVP estático para controle de garantias de contas.

## O que faz
- Cadastro de clientes
- Cadastro de contas
- Registro da venda inicial
- Registro de reposições sem reiniciar a garantia
- Dashboard simples com vencimentos e alertas

## Banco
Usa Supabase com tabelas isoladas:
- `warranty_customers`
- `warranty_accounts`
- `warranty_sales`
- `warranty_replacements`
- `warranty_sales_overview`

## Publicação
Site pensado para GitHub Pages.

## Setup
1. Aplicar `sql/setup.sql` no Supabase.
2. Publicar `index.html` e a pasta `sql/`.
3. Entrar com o PIN configurado no frontend.

> Observação: esta primeira versão mantém o mesmo padrão operacional simples do admin atual. Vale endurecer autenticação/RLS na próxima fase.
