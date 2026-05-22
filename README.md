Implementação Kubernetes





# Opções de atualização:

## Atualização do Node (Frontend)

Para atualizar a versão do Node no frontend:

1. Navegue até a pasta `frontend` na raiz do projeto
2. Edite o arquivo `Dockerfile`
3. Altere a versão na linha 1 (atualmente 20) para a versão desejada
4. Se estiver usando desenvolvimento local, atualize a versão no arquivo `package.json` e execute `npm install`

## Atualização do Python (Backend)

Para atualizar a versão do Python:

1. Edite o arquivo `Dockerfile` na raiz do projeto
2. Altere a versão `3.12 slim` para a versão desejada
3. Atualize também o arquivo `requirements.txt` se necessário

## Atualização de Dependências

Para atualizar as dependências do projeto:

```bash
# Backend
pip freeze > requirements-freeze.txt

# Frontend
npm update
```
O projeto utiliza um sistema de balanceamento de carga para garantir alta disponibilidade e distribuição de tráfego:

```
                    ┌─────────────┐
                    │   Nginx     │
                    │  (Porta 80) │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
        ┌─────▼──────┐           ┌─────▼──────┐
        │  Frontend  │           │   Backend   │
        │  (Porta 80)│           │  (Upstream) │
        └────────────┘           └──────┬──────┘
                                         │
                              ┌──────────┴──────────┐
                              │                     │
                        ┌─────▼──────┐        ┌─────▼──────┐
                        │ backend-0  │        │ backend-1  │
                        │ (Porta 5000)       │ (Porta 5001)│
                        └──────┬──────┘        └──────┬──────┘
                               │                      │
                               └──────────┬───────────┘
                                          │
                                   ┌──────▼──────┐
                                   │  PostgreSQL │
                                   │  (Porta 5432)│
                                   └─────────────┘
```

### Componentes

1. **Nginx (Load Balancer)**: Servidor que distribui as requisições entre os backends
2. **Backend-0 e Backend-1**: Duas instâncias do servidor Flask para balanceamento
3. **Frontend**: Servidor React que atende as requisições web
4. **PostgreSQL**: Banco de dados compartilhado entre os backends

### Configuração do Balanceamento

O balanceamento é configurado no arquivo `nginx/default.conf`:

```nginx
upstream backend_servers {
    server backend-0:5000;
    server backend-1:5000;
}
```

O Nginx distribui as requisições da API (`/api/`) entre os dois backends usando round-robin por padrão.

### Redes Docker

O projeto utiliza duas redes Docker para isolamento:
- **webnet**: Conecta frontend e backends

### Escalabilidade

Para adicionar mais backends:
1. Adicione um novo serviço no `docker-compose.yml`
2. Adicione o novo servidor no upstream do Nginx

# Para executar o jogo deve-se executar os seguintes comandos no terminal:
  docker-compose up
  
  _______________________________________________________________________________________________________________________________________________________________________________________________________________________________
  
# Jogo de Adivinhação com Flask

## Implantação Kubernetes (k3d)

Siga estes passos para executar o sistema em um cluster Kubernetes (k3d). As imagens do backend e do frontend devem ser publicadas no Docker Hub.

Pré-requisitos:
- `docker` (com login no Docker Hub)
- `kubectl`
- `k3d` (o ambiente do curso fornece um k3d na OVA)

1) Defina seu usuário Docker Hub:

```bash
export DOCKERHUB_USER=SEU_USUARIO_DOCKERHUB
docker login
```

2) Build e push das imagens (no contexto da raiz do repositório):

```bash
# Backend
docker build -t $DOCKERHUB_USER/guess-backend:latest -f Dockerfile .
docker push $DOCKERHUB_USER/guess-backend:latest

# Frontend (produção - build + nginx)
docker build -t $DOCKERHUB_USER/guess-frontend:latest -f frontend/Dockerfile.prod .
docker push $DOCKERHUB_USER/guess-frontend:latest
```

3) Criar o cluster k3d (exemplo mínimo):

```bash
k3d cluster create guess --agents 0
```

4) Instalar `metrics-server` (necessário para o HPA funcionar):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

5) Aplicar os manifests no diretório `k8s/`:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres-pvc.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/backend-hpa.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
```

Os manifests contêm placeholders de imagem `YOUR_DOCKERHUB_USER/guess-*`. Se você preferir, atualize as imagens diretamente usando:

```bash
kubectl -n guess-game set image deployment/backend backend=$DOCKERHUB_USER/guess-backend:latest
kubectl -n guess-game set image deployment/frontend frontend=$DOCKERHUB_USER/guess-frontend:latest
```

6) Acessando o Frontend
- Via `port-forward` (recomendado para testes locais):

```bash
kubectl -n guess-game port-forward svc/frontend 8080:80
# Acesse http://localhost:8080
```

- Ou via `NodePort` (manifest expõe `nodePort: 30080`): acesse o IP do nó k3d na porta `30080`.

Componentes instalados:
- **Namespace**: `guess-game`
- **Postgres**: `Deployment` + `PersistentVolumeClaim` + `Service` (ClusterIP)
- **Backend**: `Deployment` + `Service` (ClusterIP) + `HPA` (autoscaling/v2, CPU)
- **Frontend**: `Deployment` + `Service` (NodePort) — o container de frontend contém `nginx` que proxya `/api` para o serviço `backend` internamente

Observações:
- O HPA depende do `metrics-server` estar presente. Instale-o conforme o passo 4.
- Se preferir usar `ingress` ou `Gateway API`, substitua a exposição do frontend conforme desejado.
- Para testar o HPA, gere carga contra o backend (por exemplo com `wrk`/`hey` dentro do cluster) até que o consumo de CPU atinja o alvo configurado.


Este é um simples jogo de adivinhação desenvolvido utilizando o framework Flask. O jogador deve adivinhar uma senha criada aleatoriamente, e o sistema fornecerá feedback sobre o número de letras corretas e suas respectivas posições.

## Funcionalidades

- Criação de um novo jogo com uma senha fornecida pelo usuário.
- Adivinhe a senha e receba feedback se as letras estão corretas e/ou em posições corretas.
- As senhas são armazenadas  utilizando base64.
- As adivinhações incorretas retornam uma mensagem com dicas.
  
## Requisitos

- Python 3.8+
- Flask
- Um banco de dados local (ou um mecanismo de armazenamento configurado em `current_app.db`)
- node 18.17.0

## Instalação

1. Clone o repositório:

   ```bash
   git clone https://github.com/fams/guess_game.git
   cd guess-game
   ```

2. Crie um ambiente virtual e ative-o:

   ```bash
   python3 -m venv venv
   source venv/bin/activate  # Linux/Mac
   venv\Scripts\activate  # Windows
   ```

3. Instale as dependências:

   ```bash
   pip install -r requirements.txt
   ```

4. Configure o banco de dados com as variáveis de ambiente no arquivo start-backend.sh
    1. Para sqlite

        ```bash
            export FLASK_APP="run.py"
            export FLASK_DB_TYPE="sqlite"            # Use SQLITE
            export FLASK_DB_PATH="caminho/db.sqlite" # caminho do banco
        ```

    2. Para Postgres

        ```bash
            export FLASK_APP="run.py"
            export FLASK_DB_TYPE="postgres"       # Use postgres
            export FLASK_DB_USER="postgres"       # Usuário do banco
            export FLASK_DB_NAME="postgres"       # Nome do Banco
            export FLASK_DB_PASSWORD="secretpass" # Senha do banco
            export FLASK_DB_HOST="localhost"      # Hostname
            export FLASK_DB_PORT="5432"           # Porta
        ```

    3. Para DynamoDB

        ```bash
        export FLASK_APP="run.py"
        export FLASK_DB_TYPE="dynamodb"       # Use postgres
        export AWS_DEFAULT_REGION="us-east-1" # AWS region
        export AWS_ACCESS_KEY_ID="FAKEACCESSKEY123456" 
        export AWS_SECRET_ACCESS_KEY="FakeSecretAccessKey987654321"
        export AWS_SESSION_TOKEN="FakeSessionTokenABCDEFGHIJKLMNOPQRSTUVXYZ1234567890"
        ```

5. Execute o backend

   ```bash
   ./start-backend.sh &
   ```

6. Cuidado! verifique se o seu linux está lendo o arquivo .sh com fim de linha do windows CRLF. Para verificar utilize o vim -b start-backend.sh

## Frontend
No diretorio de frontend

1. Instale o node com o nvm. Se não tiver o nvm instalado, siga o [tutorial](https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating)

    ```bash
    nvm install 18.17.0
    nvm use 18.17.0
    # Habilite o yarn
    corepack enable
    ```

2. Instale as dependências do node com o npm:

    ```bash
    npm install
    ```

3. Exporte a url onde está executando o backend e execute o backend.

   ```bash
    export REACT_APP_BACKEND_URL=http://localhost:5000
    yarn start
   ```

## Como Jogar

### 1. Criar um novo jogo

Acesse a url do frontend http://localhost:3000

Digite uma frase secreta

Envie

Salve o game-id


### 2. Adivinhar a senha

Acesse a url do frontend http://localhost:3000

Vá para o endponint breaker

entre com o game_id que foi gerado pelo Creator

Tente adivinhar

## Estrutura do Código

### Rotas:

- **`/create`**: Cria um novo jogo. Armazena a senha codificada em base64 e retorna um `game_id`.
- **`/guess/<game_id>`**: Permite ao usuário adivinhar a senha. Compara a adivinhação com a senha armazenada e retorna o resultado.

### Classes Importantes:

- **`Guess`**: Classe responsável por gerenciar a lógica de comparação entre a senha e a tentativa do jogador.
- **`WrongAttempt`**: Exceção personalizada que é levantada quando a tentativa está incorreta.



## Melhorias Futuras

- Implementar autenticação de usuário para salvar e carregar jogos.
- Adicionar limite de tentativas.
- Melhorar a interface de feedback para as tentativas de adivinhação.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---


