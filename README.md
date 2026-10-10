# Nuke Mail

Site estático em português para criar caixas temporárias reais usando as APIs públicas Mail.tm e Mail.gw, diretamente no navegador. Publique a pasta `dist` em uma hospedagem estática com HTTPS. Não há compilação nem dependências.

Domínios são consultados ao vivo, sem lista fictícia. O filtro edu só mostra domínios realmente retornados; categorias não concedem vínculo institucional. O serviço é temporário e não garante permanência ou aceitação por outros sites. Credenciais ficam em sessionStorage. Mensagens são exibidas como texto; anexos não são suportados.

Provedores: https://mail.tm e https://mail.gw. Respeite suas condições e limites. Nenhuma chave é necessária.

Teste de integração: criação real, token e consulta de caixa Mail.tm confirmados. Contudo os testes CORS não retornaram Access-Control-Allow-Origin para o site, impedindo integração direta no navegador. Mail.gw retornou HTTP 502. Links para acesso aos provedores disponíveis como alternativa. Recebimento externo não foi testado.
