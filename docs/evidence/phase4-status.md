# Fases 3 e 4 — matriz de evidências

Atualizado em 15/11/2026. **Preparado** significa código/manifests presentes e validação local; **comprovado** exige execução indicada na coluna de evidência. Não usar este documento para afirmar que um recurso AWS foi criado antes do `terraform apply` autorizado.

| Requisito | Estado observado | Evidência atual | Para concluir |
|---|---|---|---|
| Três serviços e repositórios independentes | Local comprovado | `exports/oficina-os`, `exports/oficina-execution`, `exports/oficina-billing`: branch `main`, histórico do commit `ea5a8df`, um workflow próprio, sem remote. Testes unitários/integração anteriores e três builds Docker `:extracted-local` passaram. Os testes adicionais dos próprios clones em PostgreSQL e DynamoDB passaram em 15/11: OS 1/1, Execução 3/3, Billing 13/13. | Publicar após autorização; guardar URLs, runs CI e regras de branch. |
| Bancos próprios SQL e NoSQL | Preparado | Terraform RDS com `oficina_os` e `oficina_execution`, DynamoDB Billing; bootstrap de usuários/segredos e testes locais PostgreSQL/DynamoDB. Em 15/11, o SQL exato do bootstrap criou usuários e os dois databases em PostgreSQL 16 isolado; o contêiner descartável foi removido. | `plan` e `apply` autorizados; capturas e consulta real em cada serviço. |
| SQS, Outbox/Inbox, Saga e compensações | Local comprovado | Testes locais de reserva, pagamento simulado, conclusão, recusa, estorno e redrive; `scripts/demo-fase4.ps1` e `docs/evidence/demo-local.json`. O repositório Billing também testa `WorkOrderOpened` → DynamoDB → `BudgetReady` com ElasticMQ próprio. | Executar `verify-flow-k3s.sh` na AWS; demonstrar compensação e DLQ reais. |
| Mercado Pago testes | Parcial | Adaptador Orders, HMAC, reconciliação GET e estorno opt-in com testes simulados. | Credenciais e webhook HTTPS de testes; registrar order, confirmação e estorno reais. |
| Autenticação serverless por CPF | Preparado | Function .NET 10, 13 testes, ZIP local, Terraform Lambda/HTTP API/VPC/Secrets Manager; Compose valida CPF → JWT → tracking. | `apply` autorizado, bootstrap da OS e invocação real da URL `auth_token_url`; capturar 200/401 e tracking com JWT. |
| CI/CD da Function Auth | Local comprovado; deploy remoto pendente | Clone `exports/oficina-auth-lambda` com histórico, `main`, workflow próprio e sem remote; 13/13 testes e geração do ZIP passaram. Terraform prepara role OIDC restrita à Function. | Publicar o quarto repo autorizado, configurar três variables e guardar run de deploy verde. |
| Kubernetes e healthchecks | Preparado | Kustomize renderiza 17 recursos; manifests dos três Deployments têm liveness/readiness/startup; `smoke-k3s.sh` verifica três HTTP 200. | Aplicar no K3s AWS; capturar pods, serviços, HPAs, rollouts e smoke. |
| Terraform, IAM, OIDC e segredos | Preparado | `terraform fmt -check` e `validate` passam; backend S3 com lockfile, roles por serviço, STS 1h, segredos fora do state. | Bucket de state, `plan` revisado, `apply` autorizado e validação IAM/SSM em conta real. |
| GitHub Actions CI/CD | Preparado | Três workflows por serviço com testes unitários e integração PostgreSQL/DynamoDB; Billing também inicia ElasticMQ. Billing e Execução aplicam gate de cobertura de 80%; OS anexa relatórios sem gate, pois está abaixo do mínimo. Imagem ECR por OIDC e rollout SSM por SHA. Os testes passaram localmente nos clones; os workflows ainda não rodaram no GitHub. | Publicar repositórios, configurar variables, obter três runs verdes e comprovar rollout; proteger `main`. |
| Observabilidade | Local comprovado | Trace entre OS/Execução/Billing, métricas, nove painéis Grafana e alerta local. | Capturar logs/traces/métricas e alerta no K3s AWS; definir retenção final. |
| Cobertura >=80% por serviço e Quality Gate | **Parcial: Billing e Execução aprovados localmente; OS pendente** | A união por arquivo/linha das suítes Billing unitária (10/10) e DynamoDB/SQS (15/15) cobriu **1.147/1.374 = 83,48%** do pacote `Oficina.Billing`. Execução unitária (11/11) e PostgreSQL (3/3) cobriu **1.635/2.037 = 80,27%** do pacote `Oficina.Execution` em duas medições locais. O validador compartilhado aplicou mínimo de 80% e rejeitou fixture de 50%. OS Domínio/Integração/PostgreSQL cobriu **6.566/13.250 = 49,55%** dos pacotes Domain/Application/Infrastructure/Api; excluindo só migrations EF geradas, **2.217/4.446 = 49,87%**. O gate parcial anterior de Domain não representa a OS inteira. | Rodar os gates Billing/Execução no GitHub; ampliar cobertura OS até 80% e aplicar gate equivalente. |
| BDD | Local parcial | Cenários em `docs/bdd/saga-fase4.feature` e testes de Saga com emuladores. | Executar os cenários completos no CI por repo e guardar relatório. |
| Vídeo, PDF e entrega | Parcial | Roteiro de 15 minutos em `docs/demo-15-min.md`; `scripts/generate-phase4-submission.py` gera rascunho PDF de duas páginas com diagrama, Saga e justificativas. O PDF assinala identificação e links pendentes. | Gravar vídeo <=15 min, preencher `docs/submission-metadata.json` com nomes/RMs e URLs reais, gerar e revisar PDF final. |

## Ordem de coleta remota

1. Registrar conta/região, custo aceito e autorização de bucket de state; guardar `terraform plan` revisado sem credenciais.
2. Publicar os três repositórios de serviços e o da Auth após autorização; configurar OIDC/variables e salvar URL de cada run CI.
3. Aplicar Terraform autorizado, publicar imagens ECR, executar bootstrap K3s e `smoke-k3s.sh`.
4. Executar `verify-flow-k3s.sh`; salvar ID da OS, trace e resultado da Lambda/cliente.
5. Salvar capturas de RDS, DynamoDB, SQS/DLQ, ECR, Lambda/API Gateway, EC2/K3s e Grafana, sem exibir segredos ou tokens.
6. Gravar a apresentação e, após autorização, desmontar o ambiente; verificar custos residuais.

O módulo permite `destroy` autorizado de ECR com imagens e do bucket de pacotes com objeto pendente. RDS não preserva snapshot final e os segredos de aplicação têm recuperação desativada. Revisar o plano de destruição antes de executá-lo; o bucket de state é externo ao módulo.

O passo a passo operacional está em [preparação GitHub/AWS](../runbooks/preparacao-github-aws.md). As fontes completas de requisitos e decisões estão em [implementation-plan](../implementation-plan.md).
