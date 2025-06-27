# Diário de Bordo da Operação "Agent Zero: Produção"

Este documento serve como um registro cronológico das decisões técnicas, problemas encontrados e soluções aplicadas para transformar o ambiente de desenvolvimento do Agent Zero em uma configuração de produção estável e autocontida, pronta para deploy.

## Objetivo

Eliminar a frágil arquitetura de desenvolvimento baseada em Chamadas de Função Remota (RFC) e múltiplos contêineres, e fazer o Agent Zero rodar de forma confiável em um único contêiner Docker, ideal para ambientes como o EasyPanel.

---

## A Jornada de Depuração: Uma Saga em Duas Estratégias

Nossa colaboração para estabilizar o ambiente foi uma lição sobre a importância de trabalhar com as ferramentas existentes em vez de contorná-las.

### Estratégia 1: Contornando o `Supervisor` (O Caminho dos Erros)

Inicialmente, identificamos que o `Supervisor`, o gerenciador de processos da imagem Docker, era responsável por iniciar múltiplos serviços, incluindo alguns que pareciam desnecessários e causavam logs infinitos (`run_tunnel_api`). A primeira abordagem, lógica mas equivocada, foi desativar completamente o `Supervisor` e tentar iniciar os serviços essenciais manualmente.

1.  **Ação:** Alteramos o `docker-compose.yml` para usar um `command` customizado, apontando para um script nosso (`/exe/run_A0.sh`).
2.  **Primeiro Problema:** Ao fazer isso, o serviço de busca `SearXNG` deixou de funcionar, resultando em um erro de `ConnectionRefusedError: Cannot connect to host localhost:55510`, pois ele era iniciado pelo `Supervisor`.
3.  **A Cascata de Erros Seguintes:**
    *   Tentamos iniciar o `SearXNG` manualmente dentro do nosso script `run_A0.sh`.
    *   Isso causou um erro de `permission denied`, pois o script, vindo do Windows (via WSL), não tinha permissão de execução no Linux. Corrigimos com `chmod +x`.
    *   Em seguida, enfrentamos um erro de `No such file or directory` dentro do contêiner, pois o caminho para o executável do `SearXNG` no nosso script estava incorreto.

Neste ponto, ficou claro que estávamos reconstruindo, de forma frágil, algo que o `Supervisor` já fazia de forma robusta. Foi aqui que, com a sua intuição, mudamos de estratégia.

### Estratégia 2: A "Cirurgia" no `Supervisor` (A Solução Correta e Final)

A abordagem correta não era lutar contra o `Supervisor`, mas sim configurá-lo para trabalhar a nosso favor.

1.  **Reabilitação:** Removemos nossas customizações (`command` e o mapeamento do `run_A0.sh`) do `docker-compose.yml`, devolvendo o controle total ao `Supervisor`. Como esperado, a busca voltou a funcionar, mas a UI quebrou e os logs indesejados retornaram, confirmando que o culpado era um serviço específico.
2.  **Diagnóstico Preciso:** Usamos `docker-compose exec` para listar os arquivos de configuração do `Supervisor` em `/etc/supervisor/conf.d/`, encontrando o `supervisord.conf`.
3.  **Extração:** Lemos o conteúdo completo do `supervisord.conf` de dentro do contêiner.
4.  **Modificação Cirúrgica:** Criamos uma cópia local deste arquivo em `docker/run/fs/etc/supervisor/conf.d/`. Nesta cópia, comentamos com `#` toda a seção `[program:run_tunnel_api]`, que era a fonte de todos os problemas de instabilidade da UI e dos logs.
5.  **Injeção da Nova Configuração:** Adicionamos um mapeamento de volume final ao `docker-compose.yml`, instruindo-o a montar nosso `supervisord.conf` modificado sobre o original dentro do contêiner:
    ```yaml
    - ./fs/etc/supervisor/conf.d/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf
    ```

## Resultado Final

Com esta última alteração, alcançamos o estado ideal:
*   O `Supervisor` está ativo e gerenciando os processos.
*   Os serviços essenciais, como `run_ui` e `run_searxng`, são iniciados corretamente por ele.
*   O serviço problemático, `run_tunnel_api`, é completamente ignorado.

O resultado é um único contêiner estável, previsível e limpo, acessível em `http://localhost:50001`, com a interface funcionando, a busca operacional e os logs sem ruído. O sistema está agora verdadeiramente pronto para produção.

---

## 26/06/2024: Preparação para o Deploy e a Estratégia do Dockerfile de Produção

**Situação Atual:** Após o sucesso em versionar o projeto no repositório GitHub `Apex7AI/Apex7aip`, o próximo passo lógico é o deploy no EasyPanel.

**Decisão Técnica e Racional:**

O `Dockerfile` presente no repositório (`docker/run/Dockerfile`) era o original do projeto `frdel/agent-zero`, projetado para um processo de build complexo e dependente de scripts (`/ins/*.sh`) e uma imagem base privada. Este `Dockerfile` não é adequado para um deploy limpo e transparente em um ambiente como o EasyPanel.

Para garantir um deploy robusto, previsível e autocontido, decidimos adotar um **`Dockerfile` de produção dedicado**. Este novo `Dockerfile` será o arquivo oficial para builds de produção e seguirá as melhores práticas:

1.  **Base Pública e Leve:** Utilizará a imagem `python:3.11-slim` como base, que é segura, otimizada e mantida pela comunidade.
2.  **Instalação de Dependências Explícitas:** Instalará o `git` via `apt-get`, uma dependência que identificamos ser necessária durante a depuração. As dependências Python serão instaladas via `pip` a partir do `requirements.txt`.
3.  **Cópia Integral do Código:** Copiará todo o código-fonte do repositório para o contêiner (`COPY . .`), garantindo que o build use exatamente o que foi versionado.
4.  **Ponto de Entrada Único e Claro:** Definirá o comando de inicialização `CMD ["python", "run_ui.py"]`, que corresponde à nossa arquitetura de serviço único estabilizada.
5.  **Exposição de Porta Correta:** Exporá a porta `80`, que é a porta em que a aplicação escuta dentro do contêiner.

Esta abordagem **não afeta o ambiente de desenvolvimento local**. O desenvolvimento continuará usando o `docker-compose.yml`, que utiliza volumes para o "modo rápido", enquanto o EasyPanel usará o novo `Dockerfile` de produção para criar a imagem na nuvem.

**Próximos Passos Imediatos:**
1. Atualizar este diário de bordo.
2. Substituir o conteúdo de `docker/run/Dockerfile` pelo novo `Dockerfile` de produção.
3. Fazer o commit e push desta alteração para o GitHub, deixando o repositório pronto para o deploy.

---

## Estado Atual e Procedimento de Execução

Com todas as correções aplicadas, temos um ambiente de produção limpo, estável e previsível.

**Para iniciar o ambiente (a partir do diretório `docker/run`):**

**1. Limpeza Completa (Recomendado se houver problemas):**
```powershell
docker-compose down -v
```

**2. Iniciar o Ambiente Corrigido:**
```powershell
docker-compose up -d
```

O resultado é um único contêiner estável, acessível em `http://localhost:50001`, com os logs normalizados e todas as ferramentas, incluindo o `browser_agent`, prontas para funcionar.

-----------------
## 25/06/2025: A Caça ao Último Fantasma - O Script de Inicialização

Após estabilizar o ambiente e tomar o controle do `Supervisor`, um último erro crítico surgiu ao tentar usar a ferramenta de busca (`search_engine`): `ConnectionRefusedError: Cannot connect to host localhost:55510`.

*   **Diagnóstico:** O erro confirmou que a ferramenta de busca ainda dependia do serviço `SearXNG`. Ao desativar o `Supervisor`, o `SearXNG` não era mais iniciado, mas a aplicação principal ainda tentava se conectar a ele.

*   **A Investigação e a Solução Final:** A solução era iniciar o `SearXNG` manualmente a partir do nosso script de controle, o `run_A0.sh`. No entanto, a implementação foi marcada por uma série de pequenos erros que mascararam a solução real:
    1.  **A Armadilha do `exec`:** A primeira versão do script usava `exec` para iniciar a aplicação Python. No Linux, `exec` substitui o processo do script pelo processo da aplicação, o que fazia com que o `SearXNG` (iniciado em segundo plano) morresse junto com o script.
    2.  **O Fantasma do Volume Ausente:** Após corrigir o problema do `exec`, o erro persistiu. A causa final e mais sutil foi descoberta ao revisar o `docker-compose.yml`: nós estávamos editando o `run_A0.sh` localmente, mas o arquivo **nunca foi mapeado como um volume para dentro do contêiner**. O Docker estava executando a versão antiga do script, que existia na imagem base.

*   **A Solução Definitiva:**
    1.  **Script `run_A0.sh` Corrigido:** O script foi ajustado para iniciar o `SearXNG` em segundo plano (`&`) e, em seguida, iniciar a aplicação Python em primeiro plano (sem `exec`), garantindo que ambos os processos permaneçam vivos. Um `sleep` foi adicionado para dar tempo ao `SearXNG` de inicializar.
    2.  **Mapeamento do Volume:** A linha `- ./fs/exe/run_A0.sh:/exe/run_A0.sh` foi adicionada ao `docker-compose.yml`, garantindo que nossa versão corrigida do script seja de fato utilizada pelo contêiner.

Esta alteração finaliza o processo de estabilização, resultando em um agente verdadeiramente autocontido e funcional, pronto para os próximos passos. 

---

## 27/06/2024: Deploy no EasyPanel via Docker Compose

Após estabilizar o ambiente local, a próxima fase foi realizar o deploy no EasyPanel, utilizando o método de `Compose` a partir do repositório Git.

**Decisões e Ajustes de Deploy:**

1.  **Caminho de Build:** Durante a configuração no painel do EasyPanel, foi identificado que o caminho de build correto a ser fornecido é `/docker/run` (com a barra no início).

2.  **Visibilidade do Repositório:** O repositório no GitHub precisou ser tornado **Público** para que o EasyPanel pudesse acessá-lo e validar o caminho de build. A alternativa, para repositórios privados, seria configurar uma "Deploy Key" SSH.

3.  **Erro `env file not found`:** A primeira tentativa de deploy falhou com um erro indicando que o arquivo `.env` não foi encontrado.
    *   **Causa:** Nosso arquivo `docker-compose.yml` continha a diretiva `env_file: - .env`, que instrui o Docker a carregar variáveis de um arquivo `.env` local. Este arquivo não existe no repositório por razões de segurança.
    *   **Solução:** Modificamos o `docker-compose.yml` e comentamos a diretiva, forçando o EasyPanel a usar as variáveis de ambiente configuradas em sua própria interface gráfica.

4.  **Avisos de `container_name` e `ports`:** O EasyPanel emitiu avisos informando que essas diretivas não deveriam ser usadas.
    *   **Causa:** Ambientes gerenciados como o EasyPanel controlam os nomes dos contêineres e o roteamento de portas automaticamente para evitar conflitos.
    *   **Solução:** Removemos as diretivas `container_name` e `ports` do `docker-compose.yml`, delegando esse controle para a plataforma.

5.  **Erro `No such file or directory` na Inicialização:** Após o deploy bem-sucedido, a aplicação não subia, e os logs mostravam um erro em `/exe/run_A0.sh` ao tentar iniciar o SearXNG.
    *   **Causa:** Nossa configuração com `Supervisor` já inicia o `run_searxng` como um serviço separado. O script `run_A0.sh` (executado pelo serviço `run_ui`) também tentava iniciar o `SearXNG`, causando um conflito e um erro fatal, pois o caminho do executável no ambiente de produção do EasyPanel era diferente.
    *   **Solução:** Editamos o `run_A0.sh` e comentamos as linhas que tentavam iniciar o `SearXNG` e o `sleep` relacionado, tornando o `Supervisor` a única fonte de verdade para a inicialização de serviços.

### **IMPORTANTE: Como Restaurar para o Ambiente de Desenvolvimento Local**

A alteração feita para o deploy no EasyPanel **quebra a configuração local** no Docker Desktop, pois o ambiente local depende de diretivas específicas no `docker-compose.yml`.

Para voltar a rodar o projeto localmente, é necessário **desfazer o comentário** no arquivo `docker/run/docker-compose.yml`:

**Mude isto:**
```yaml
    # env_file:
    #  - .env
```

**De volta para isto:**
```yaml
    container_name: agent-zero-run
    ports:
      - "50001:80"
    env_file:
      - .env
```

Esta documentação garante que podemos alternar entre o modo de deploy (EasyPanel) e o modo de desenvolvimento (local) sem perda de configuração. 