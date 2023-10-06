# Maestro

## Manual de Utilização do CDK

### Via Shell Script

Criar um arquivo `.json` usando como base o arquivo `env_sample.json`, alterando de acordo com as informações do projeto que será executado.

Estrutura do arquivo `env_sample.json

{
  "test": false, // false - facilita na remoção dos recursos, caso seja um ambiente temporário.
                 // true - Ativa uma flag nos recursos que dificulta a deleção acidental. Ambiente de produção, ou 
                 // ambientes permanentes.
  "environment": "staging", // valores aceitáveis ('production'|'staging'|'development'|'prod'|'stag'|'dev')
  "secrets": "{\"PORT\":3000}", // Pode conter as variáveis de amiente do projeto, para serem escritas no Secret Manager.
                                // PORT=3000 é obrigatório
  "account": {
    "name": "NomeDaContaAWS" // Um nome qualquer que identifique a conta AWS que está recebendo o ambiente
  },
  "repository": {
    "url": "https://github.com/veezor/static_site", // Repositório do projeto a ser executado, bitbucket,
                                                    // github, codecommit são URLs compativéis.
    "branch": "development" // Nome da branch a ser utilizada. Podendo ser um nome ficticio, pois o ambiente
                            // utilizara esse campo para nomear os recursos criados.
  },
  "vpc": {
    "name": "veezor-prod", // Opcional. Caso já possua uma VPC criada na conta e que queira reutiliza-la.
                           // Caso queira criar uma nova VPC, será criada com o nome inserido nesse campo.
    "cidr": "10.0.0.0/16", // Obrigatório. CIDR que deverá ser utilizada
    "id": "vpc-0cbbf8d9ff57739e7", // Opcional. Caso já possua uma VPC criada, e queira reutiliza-la, esse campo é
                                   // obrigatório, e deve conter o ID da VPC ã ser utilizada.
                                   // Caso contrário, esse campo deve estar vazio.
    "subnets": {
      "private": "[]", // Opcional. Somente utilizado no caso da VPC já existir, e queira utilizar certas subnets
                       // privadas para o projeto.
      "public": "[]"   // Opcional. Somente utilizado no caso da VPC já existir, e queira utilizar certas subnets
                       // publicas para o projeto.
    }
  },
  "loadbalancer":{
    "scheme": "internet-facing" // Obrigatório
  },
  "efs": [], // Utilizado para montar EFSs adicionais nos containers. Doocumentação precisa ser atualizada.
  "tags": "[[\"Owner\",\"OAntagonista\"],[\"Environment\",\"Development\"],[\"Project\", \"oantagonista\"]]"
}

> **Para todas as execuções de script desta documentação, pode-se complementar o comando com a instrução** <br> `--profile <AWS Account>` **caso o AWS-CLI esteja configurado na máquina com a utilização de profiles.** <br>

Executar o comando a seguir e seguir as instruções. <br>
``` bash
 $ ./maestro_run.sh --env-file env_sample.json
```
Caso necessário, dê permissões para executar o .sh com o comando: <br>
``` bash
 $ chmod +x maestro_run.sh
```

<br>
Descrição das opçoes exibidas pelo script maestro_run.sh 
1) Git_update --> Atualiza o código local de acordo com a branch em uso, caso haja alteraçoes. Mesmo que utilizar git fetch e git update no terminal.
2) NPM_Update --> Instala ou atualiza as bibliotecas (pasta node_modules) utilizadas no projeto.
3) Bootstrap --> Necessário ser executado em contas AWS que nunca tiveram algum contato com CDK, caso esse passo seja pulado, os demais deverão falhar, por falta da configuração inicial exigida pelo CDK. Só necessita ser executado uma única vez em cada conta.
4) VPC --> Responsável pela criação da infraestrutura de REDE, como VPC, subnets, rotas etc.
5) Maestro_infra --> Responsável pela criação do codebuild, security groups, policies e roles.
6) Quit --> Encerra a execução do script.


## Premissas para o início da transformação

### Do versionamento do código

É essencial que **TODAS** as mudanças feitas durante o processo de transformação para migração sejam iterativamente e imediatamente salvas. Fazer o trabalho na máquina local e não criar commits e pushes ao longo do processo nos expõe a um risco desnecessário e dificulta causando grandes retrabalhos no futuro. Se não tiver acesso de escrita ao repositório do cliente, é mandatório a criação de um fork ou de um projeto privado dentro da conta da Veezor para podermos garantir eficiência no processo.


### Das versões de ferramentas do workload

É determinante para a aceleração da transformação do workload uma minuciosa inspeção nos ambientes atuais da versão de cada linguagem usada como node, php, ruby, python e ferramentas como yarn, npm, bundler, pip, etc.

Para muitas dessas ferramentas, pode-se usar múltiplas versões especialmente quando se está trabalhando em diversos projetos em paralelo e para isso recomendamos usar o `asdf-vm`

Mais informações:
* [Getting Started | asdf](https://asdf-vm.com/guide/getting-started.html#_1-install-dependencies)

**Atenção: Ignorar essa diretiva pode custar muitas horas desnecessárias de trabalho investigando erros misteriosos que só estão acontecendo por causa do desbalanceamento das versões usadas!**


## Considerações para abstração

### Descritivo de projeto para os buildpacks
Todo projeto precisa de um arquivo descritivo que compõe as dependências do builder, buildpacks e facilita a automação do processo de build. Esse arquivo por padrão fica na raiz do projeto e é chamado `project.toml`. A maior parte dos workloads pode ser resolvidos com o builder mais atual do heroku conforme o exemplo abaixo:

``` toml
[project]
id = "com.veezor.meu-projeto"
name = "Meu Projeto"
version = "1.0"

[build]
builder = "heroku/buildpacks:20"
```

Para mais informações sobre as possibilidades de informações que podem ser incluídas neste arquivo consulte [project.toml · Cloud Native Buildpacks](https://buildpacks.io/docs/reference/config/project-descriptor/)

**TODO:** Precisamos fazer com que esse arquivo seja criado automaticamente pelo processo de build e coloque o builder e buildpacks personalizados vindos do SecretManager. <br> 
Exemplo: `PACK_PROJECT_BUILDER="heroku/buildpacks:20", PACK_PROJECT_BUILDPACKS="..."`


### Script para receber parâmetros

#### Tags para recursos

Precisamos criar um script para abstrair a passagem dos parâmetros que vão ser passados para o CDK


## Troubleshooting de Workloads

### Criando um container localmente

#### Preparando o ambiente local

Para fazer o build local, é necessário ter o [docker](https://docs.docker.com/get-docker/) e o [pack CLI](https://buildpacks.io/docs/tools/pack/#install) disponíveis na máquina


#### Rodando o build

Para rodar o build, é necessário fazer o clone do projeto git do workload e estar na pasta principal do projeto e então executar o comando abaixo:

``` bash
$ pack build <meu-projeto>
```

Importante notar que o comando acima deve falhar caso não haja a definição de um builder que pode ser feita através de um parâmetro ou da criação do descritivo de projeto na raiz conforme descrito [aqui](https://docs.google.com/document/d/1pOWuT7AJ0RdKesaMTyb_j7Or0aod2bNsGVIHOruIgVQ/edit#heading=h.9zdyoeshijcx)


#### Adicionando variáveis de ambiente atuais

Muitos projetos dependem da existência de variáveis de ambiente para conseguir executar o processo de build. No processo de migração e transformação é natural que novas variáveis serão criadas e a melhor forma de manter tudo organizado é criando um arquivo .env na raiz do projeto e colando lá as variáveis no formato `VAR=valor` e passando o parâmetro para o comando conforme abaixo:

``` bash
$ pack build <meu-projeto> --env-file .env
```

**Importante:** após a validação local do build, esses valores devem ir para o secret manager da AWS para fazerem parte do processo de automação.


#### Acessando recursos locais

Muitos processos de build precisam de acesso a recursos como bases de dados, memória, filas, etc. Se você estiver rodando um desses serviços localmente, pode usar o ip `172.17.0.1` para servir como seu `localhost` quando rodando o `pack build`.


### Entrando em um container localmente

#### Usando docker run para rodar o processo padrão

Para rodar um container criado com o `pack build` localmente com o processo padrão, utilize o seguinte comando substituindo o parâmetro `<nome-do-container>` com o nome dado ao criar o container:

``` bash
$ docker run –env-file .env –rm -it <nome-do-container>
```

#### Usando docker run para entrar no container

Para rodar um container criado com o `pack build` localmente, utilize o seguinte comando substituindo o parâmetro `<nome-do-container>` com o nome dado ao criar o container:

``` bash
$ docker run –rm –entrypoint launcher -it <nome-do-container>
```

Mais informações sobre como rodar o container sobrescrevendo os parâmetros podem ser encontrados em [Specify launch process · Cloud Native Buildpacks](https://buildpacks.io/docs/app-developer-guide/run-an-app/)


## Resolvendo erros gerais

### Erros de string, validação de URLs, etc

Alguns erros podem ser consequência de sintaxe de arquivos como o .env que entre as chaves e valor contém aspas como por exemplo:

`FOO="bar"` <br>
`DATABASE_URL="mysql2://user:pass@database.com:5432/teste"`

Devem mudar para

`FOO=bar` <br>
`DATABASE_URL=mysql2://user:pass@database.com:5432/teste`

### Erros de caracteres faltando ou esperados

Verifique se existir um Procfile se tem alguma linha sem espaço entre o processo e o comando como por exemplo:

`web:comando blah`

Deve mudar para

`web: comando blah`


## Node.js

### Documentação sobre o uso do node.js com buildpacks

A maior parte da documentação específica de utilização de buildpacks com o node.js encontra-se no site do heroku e pode ser revisada usando os endereços abaixo:

* [Getting Started on Heroku with Node.js](https://devcenter.heroku.com/articles/getting-started-with-nodejs?singlepage=true)
* [Deploying Node.js Apps on Heroku](https://devcenter.heroku.com/articles/deploying-nodejs)
* [Heroku Node.js Support](https://devcenter.heroku.com/articles/nodejs-support)
* [Troubleshooting Node.js Deploys | Heroku Dev Center](https://devcenter.heroku.com/articles/troubleshooting-node-deploys)
* [Let It Crash: Best Practices for Handling Node.js Errors on Shutdown | Heroku](https://blog.heroku.com/best-practices-nodejs-errors)
* [Deploying an Angular Universal App to Heroku | by Augie Gardner](https://medium.com/augie-gardner/deploying-an-angular-universal-app-to-heroku-eca2b7966947)


### Criação do Procfile

O buildpack padrão de node.js consegue criar o `procfile` automaticamente com um processo padrão do tipo `web` caso exista um arquivo na raiz do projeto chamado `index.js` ou `server.js` ([Referência](https://github.com/heroku/buildpacks-nodejs/blob/daafb50f1017e51a005d5adcf8145b9c5245ee39/buildpacks/nodejs-engine/lib/build.sh#L236-L248)). Outra forma é definindo-se no manifesto do node.js chamado `package.json` que em geral fica na raiz do projeto um script chamado `start` ([Referência npm](https://github.com/heroku/buildpacks-nodejs/blob/daafb50f1017e51a005d5adcf8145b9c5245ee39/buildpacks/npm/lib/build.sh#L216-L221), [Referência yarn](https://github.com/heroku/buildpacks-nodejs/blob/5f21334ca7e58130a1fae2ebb781427a74ea75f2/buildpacks/yarn/lib/build.sh#L144-L149)) conforme o exemplo abaixo:

``` json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "engines": {
    "node": "16.14.0",
    "npm": "8.5.0"
  },
  "scripts": {
    "start": "node dist/server/main",
    …
  }
  …
}
```

### Utilização de ferramentas de monitoramento de processos

O gerenciamento do processo que vai rodar no container é feito pelo ECS e desta forma não se faz necessário a utilização de ferramentas como [PM2](https://pm2.keymetrics.io/) ou [forever](https://github.com/foreversd/forever) pois caso eles parem, o ECS providencia a substituição do container.

Caso o PM2 seja por algum motivo indispensável para a aplicação, aqui segue um manual de como integrar ele com o ambiente: [PM2 - Heroku Integration](https://pm2.keymetrics.io/docs/integrations/heroku/)


### Execução de comandos antes e após a instalação de bibliotecas

Para que sejam executados comandos posteriores à instalação das bibliotecas definidas pelo arquivo de manifesto `package.json`, é necessário definir um script com o nome `heroku-postbuild` e dessa forma o buildpack vai automaticamente executar após a conclusão da instalação. Segue exemplo abaixo:

``` json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "engines": {
    "node": "16.14.0",
    "npm": "8.5.0"
  },
  "scripts": {
    "start": "node dist/server",
    "postinstall": "ng build",
    "build:ssr": "ng build —-prod && ng run meu-projeto:server:production",
    "stage:environment-config": "cp src/environments/environment.prod.ts src/environments/environment.ts",
    "heroku-prebuild": "npm run stage:environment-config"
    "heroku-postbuild": "npm run build:ssr"
    …
  }
  …
}
```

**Importante:** Sem o processo do `heroku-postbuild`, o workload pode não funcionar pois não vai gerar os artefatos usados para execução em produção.


### Utilizando bibliotecas privadas

Caso o workload necessite utilizar bibliotecas privadas é importante que as credenciais sejam mantidas fora do código no repositório. Para facilitar esse procedimento, utilize ou crie um arquivo `.npmrc` na raiz do projeto com um conteúdo semelhante ao de baixo, substituindo `<escopo>` pelo nome do escopo do pacote desejado e `<hostname-do-registro-privado>` pela base da URL do repositório:

`@<escopo>:registry=https://<hostname-do-registro-privado>//<hostname-do-registro-privado>/:_authToken=${NPM_TOKEN}`

**Importante:** _Para rodar o comando_ `pack build` _durante o processo de automação é importante colocar a variável_ `NPM_TOKEN` _no secret manager e para rodar localmente não esqueça de passar como parâmetro a variável de ambiente_ `NPM_TOKEN` _com o token equivalente como por exemplo:_

`$ pack build <nome-do-workload> -e NPM_TOKEN=<valor-do-token>`

O `NPM_TOKEN` para o Github é o PAT, informações de como obter: <br> https://docs.github.com/pt/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token


### Explicitação de bibliotecas globais

Algumas bibliotecas podem estar instaladas localmente na máquina dos desenvolvedores de forma global e com isso podem impedir o processo de build de continuar. Essas dependências precisam ser explicitadas no arquivo manifesto do node.js que é o `package.json`. Exemplos de bibliotecas que podem ser necessárias são o `webpack` e …

Para instalar, execute o comando da ferramenta usada pelo workload, as mais conhecidas são `npm` e `yarn`. Para diferenciar, se o projeto tiver um arquivo chamado `package-lock.json`, ele utiliza `npm` e se tiver `yarn.lock` ele utiliza o `yarn`. Lembrando que se tiver ambos, é necessário escolher apenas um pois de outra forma o buildpack vai falhar. Após identificar o gerenciador de pacotes, utilize um dos comandos abaixo para instalar, substituindo o parâmetro `<nome-do-pacote>` com o pacote desejado:

``` bash
$ npm install <nome-do-pacote>
```

ou 

``` bash
$ yarn install <nome-do-pacote>
```


### Definições de versão dos engines

Para garantir um build estável é importante definir versões de engines do workload dentro do arquivo de manifesto do node.js chamado `package.json` que em geral fica na raiz do projeto. Um exemplo do trecho pode ser visto abaixo:

``` json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "engines": {
    "node": "16.14.0",
    "npm": "8.5.0"
  },
  "scripts": {
    "start": "node dist/server",
    …
  }
  …
}

```


### Conflitos de versões por causa de dependências `npm` ou `yarn`

Especialmente em projetos legados, é comum que dependências resolvam versões de bibliotecas de forma a compatibilizar versões (^) ou aproximar versões (~) e isso pode trazer diversos problemas na hora do build. Mesmo que se force uma versão específica da biblioteca, uma dependência pode causar a resolução a se tornar diferente da determinada. Para entender o porquê de mesmo determinando a versão está sendo instalada uma versão maior basta digitar o seguinte comando:

`$ yarn why <nome-do-pacote>`

ou

`$ npm ls <nome-do-pacote>`

Neste caso, se a biblioteca em questão já estiver listada no bloco dependencies, a melhor forma é criar um bloco resolutions forçando a biblioteca que está compatibilizando ou aproximando as versões a usar a versão desejada conforme o exemplo abaixo onde definimos o pacote em questão como webpack:

``` json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "engines": {
    "node": "16.14.0",
    "npm": "8.5.0"
  },
  "scripts": {
    "start": "node dist/server"
  },
  "dependencies": {
    "webpack": "1.2.3",
    "@rails/webpacker": "4.46.0"
    …
  },
}
```

Rodando então o comando `yarn why` webpack teremos:

``` bash
yarn why v1.22.17
[1/4] Why do we have the module "webpack"...?
[2/4] Initialising dependency graph...
[3/4] Finding dependency...
[4/4] Calculating file sizes...
=> Found "webpack@4.29.5"
info Has been hoisted to "webpack"
info This module exists because it´s specified in "dependencies".
info Disk size without dependencies: "2.3MB"
info Disk size with unique dependencies: "8.13MB"
info Disk size with transitive dependencies: "25.29MB"
info Number of shared dependencies: 124
=> Found "@rails/webpacker#webpack@4.46.0"
info This module exists because "@rails#webpacker" depends on it.
info Disk size without dependencies: "2.41MB"
info Disk size with unique dependencies: "8.19MB"
info Disk size with transitive dependencies: "25.35MB"
info Number of shared dependencies: 123
Done in 1.27s.
```

Dado que a dependência está levando a versão declarada (4.29.5) para a versão compatibilizada (4.46.0), a solução para forçar a resolução na versão desejada é ao invés de ter webpack como uma dependência direta, forçar sua resolução na dependência para a versão desejada conforme abaixo:

``` json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "engines": {
    "node": "16.14.0",
    "npm": "8.5.0"
  },
  "scripts": {
    "start": "node dist/server"
  },
  "dependencies": {
    "webpack": "1.2.3",
    "@rails/webpacker": "4.46.0",
    …
  },
  "resolutions": {
    "@rails/webpacker/webpack": "4.29.5"
  },
  …
}
```

**TODO:** Fazer exemplo com `npm` que usa overrides, por enquanto, abaixo tem documentação vasta a respeito:

Mais informações em:
* [Selective dependency resolutions | Yarn](https://classic.yarnpkg.com/lang/en/docs/selective-version-resolutions/)
* [GitHub - rogeriochaves/npm-force-resolutions: Force npm to install a specific transitive dependency version](https://github.com/rogeriochaves/npm-force-resolutions)
* [package.json - npm Docs](https://docs.npmjs.com/cli/v8/configuring-npm/package-json#overrides)
* [npm equivalent of yarn resolutions? - package.json](https://stackoverflow.com/questions/52416312/npm-equivalent-of-yarn-resolutions)


## Otimizando performance do build

### Cache dos módulos do npm/yarn

Para acelerar o tempo de build, pode-se definir a variável de ambiente abaixo. Lembrando que ao encontrar problemas, uma das estratégias é retirar o cache para buscar reconstruir o build do zero:

* `NODE_MODULES_CACHE=true`


## Reduzindo ruídos nos logs do node e npm

### Configurando variáveis de ambiente

Variáveis de ambiente que ajudam na redução de ruídos nos logs especialmente quando existem muitos `warnings` e `infos` que apenas dificultam a leitura:

* `NODE_VERBOSE=false`
* `NPM_CONFIG_LOGLEVEL=error`
* `NO_UPDATE_NOTIFIER=true`

### Configurando o `.npmrc`

Pode-se definir um atributo no arquivo `.npmrc` que inibe boa parte das mensagens desnecessárias através da linha abaixo:

`loglevel=silent`


## Acesso via SSM nas tasks 

Necessário o uso do `--profile` ou das credenciais exportadas no console, passar o nome do cluster e o ID da task

``` bash
aws ecs execute-command \
    --region $AWS_REGION \
    --cluster <CLUSTER_NAME>\
    --task <TASK_ID> \
    --container <CONTAINE_NAME>\
    --command "launcher bash" \
    --interactive
```


## Roadmap

### Provisionamento de ambientes únicos

Adicionar hash ou um elemento nos stacks que evitem conflito com outros ambientes.

### Automação de provisionamento de recursos auxiliares

Automatizar também o provisionamento de bancos de dados RDS/Aurora, Elasticache(Redis), OpenSearch

### Agregar AWS Inspector

Configurar o ECR para utilizar o AWS Inspector

### Obter métricas de "compliance"

Obter números a partir do security hub e outras ferramentas do quanto(em números ou porcentagem) que a stack está compliance.

### Webhooks de deploy

Poder sinalizar deploys para newrelic, honeybadger, etc…

* [Tracking Deployments - Ruby HoneyBadger Documentation](https://docs.honeybadger.io/lib/ruby/getting-started/tracking-deployments/#heroku-deployment-tracking)
* [Heroku: Install the New Relic add-on](https://docs.newrelic.com/docs/accounts/install-new-relic/partner-based-installation/heroku-install-new-relic-add/#deployment)
