# Fechamento da entrega Fase 4

1. Após publicar os três repositórios e gravar o vídeo de até 15 minutos, copie `docs/submission-metadata.example.json` para `docs/submission-metadata.json`.
2. Preencha nome e RM de cada participante, URLs HTTPS dos repositórios OS, Execução e Billing, e URL pública ou não listada do vídeo. Não inclua tokens ou credenciais.
3. Execute `python scripts/generate-phase4-submission.py --output output/pdf/fiap-fase4-entrega.pdf` usando Python com `reportlab` instalado.
4. Abra as duas páginas. Confira identificação, URLs clicáveis, arquitetura, Saga, tecnologia e ausência do aviso **RASCUNHO**. Teste os links antes de enviar o arquivo ao portal FIAP.

O gerador sem metadados produz `output/pdf/fiap-fase4-entrega-rascunho.pdf` com aviso visível. Esse arquivo não é a entrega final. O documento solicitado pelo enunciado também depende do vídeo e dos repositórios publicados.
