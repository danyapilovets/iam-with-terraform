# Банківська міні-платформа: що я зробив і як це запустити

> **Це навчальний проєкт.** Я раніше не працював у банках, тому спеціально спробував повторити те, що роблять DevOps/Data інженери  в фінансовій сфері: розділив права, описав інфру в Terraform і підняв усе в Kubernetes.

---

## 1. Про що взагалі проєкт

* **Сенс**: приймати банківські транзакції через невеличкий API, передавати їх у Kafka, складати сирі дані в S3 і вже там запускати ETL-процеси на Airflow.

```
                ┌────────────┐
                │  FastAPI   │  (Producer)
                └────┬───────┘
                     │ HTTP
                     ▼
                ┌────────────┐            ┌───────────┐
                │  Kafka     │  ────────▶ │  Consumer │ ──▶ S3
                └────┬───────┘            └───────────┘
                     │
                     ▼
                PostgreSQL (OLTP)
                     │
                     ▼
                 Airflow ETL  ──▶  Аналітичні таблиці / звіти
```

---

## 2. Швидкий гайд по запуску

### 1. Локальний запуск у minikube

```bash
# 1. Підняти кластер
minikube start --cpus 6 --memory 6g

# 2. Переключити docker-env, щоб образи будувалися всередину minikube
eval $(minikube -p minikube docker-env)

# 3. Зібрати необхідний образ (є зручна ціль у Makefile)
make build-consumer

# 4. Встановити Flux у кластер
make flux-install

# 5. Підключити GitRepository та Kustomization
make flux-apply

# 6. Перевірити статус
flux get kustomizations -A

# 7. Перевірити поди
kubectl get pods -n dev
```

> У локальному режимі секрети читаються через **IAM user** (`iam_minikube_user.tf`). Це спрощення тільки для демо; у prod використовуються ролі.

### 2.2 План/аплай у AWS

```bash
# Увімкніть потрібний профіль
export AWS_PROFILE=<your-aws-profile>

# Перейти до папки середовища
cd infra/dev

# Перевірити
terraform init
terraform plan

# Створити ресурси
terraform apply -auto-approve
```

> Усі ресурси збираються у регіоні `eu-central-1`, імена мають префікс `iwt-dev-*`.

---

## 3. Як організовано репозиторій

| Шлях | Що лежить |
|------|-----------|
| `infra/` | Terraform-код. Папка `dev/` - готове оточення, `modules/` - перевикористовувані модулі (S3, IAM-роль, VPC endpoint, тощо). |
| `k8s/` | GitOps-маніфести для Flux. Для локального кластера - `local-cluster/environments/dev`. |
| `apps/` | Початковий код сервісів і Helm-чарти (`producer`, `kafka-consumer`, `airflow`). |
| `Makefile` | Основні команди: форматування, `terraform plan/apply`, збірка Helm charts та повний `make deploy`. |
| `.github/workflows/` | Автоматична збірка Docker-образів і публікація Helm-чартів у GitHub Container Registry. |

---

## 4. Технології та чому саме вони

| Компонент | Навіщо |
|-----------|--------|
| **Terraform** | Описує та версіонує інфраструктуру (IAM, S3, VPC, EC2). |
| **AWS** | Хмара, де крутиться все: обчислення, мережа, сховище. |
| **Kubernetes (minikube/EKS)** | Оркестрація контейнерів, авто-скейлінг сервісів. |
| **Helm** | Пакує налаштування сервісів у чарти. |
| **FluxCD** | GitOps-движок: автоматично застосовує чарти з репозиторію у кластер. |
| **GitHub Actions** | Будує Docker-образи та публікує чарти/образи. |
| **Makefile** | Зручні шорткати: `make plan`, `make flux-install` тощо. |
| **Pre-commit hooks** | Автоматичний `terraform fmt`, `tflint`, перевірка YAML перед комітом. |
| **FastAPI (Producer)** | Приймає HTTP-транзакції, пише у БД та Kafka. |
| **Kafka** | Черга подій для асинхронної обробки. |
| **Kafka Consumer** | Знімає батч подій, кладе у S3 архів. |
| **Airflow** | Регулярна ETL-обробка даних з S3. |
| **PostgreSQL** | Операційна база для Producer. |
| **External Secrets** | Тягне секрети з AWS Secrets Manager у Kubernetes. |
| **CloudWatch (optional)** | Моніторинг демо-EC2, якщо потрібен. |

> Цього мінімуму достатньо, щоби швидко пояснити архітектуру на співбесіді.

---

## 5. Ролі IAM і мінімальні привілеї

| Роль | Для чого | Ключові дозволи |
|------|----------|-----------------|
| `terraform_infrastructure_role` | дає Terraform право створювати все, що прописане в коді | `ec2:*`, `s3:*`, `iam:*` (тільки в `eu-central-1`) |
| `airflow_etl_role` | читає/пише у S3 ~~, бере секрети для БД~~ **(S3 + Secrets Manager)** | `s3:GetObject`, `s3:PutObject`, `secretsmanager:GetSecretValue` |
| `producer_transaction_role` | пише транзакції в S3 | `s3:PutObject`, `secretsmanager:GetSecretValue` |
| `role_kafka_consumer` | читає Kafka, архівує файли у S3 | `s3:PutObject`, `s3:GetObject` |
| `external_secrets_role` | дає External Secrets Operator читати потрібні секрети | `secretsmanager:GetSecretValue` (namespace-scoped) |
| `ec2_demo_role` | демо-інстанс; опціонально CloudWatch Agent для метрик | `logs:*` (можна вимкнути), `cloudwatch:PutMetricData` |

> Для minikube є окремий **IAM user** із токеном у Secrets Manager. У production не використовується.

---

## 6. Як компоненти спілкуються між собою

1. **Producer (FastAPI)** приймає HTTP-запит з транзакцією, пише її у PostgreSQL і відправляє до Kafka `banking.transactions`.
2. **Kafka-consumer** слухає топік, пакує батч у файл і кладе в S3 bucket `iwt-dev-data`.
3. **Airflow DAG** бачить новий об’єкт у S3, тягне файл, обробляє дані та зберігає агрегати назад у S3 / у окрему таблицю.
4. Звідти можна робити BI або тренувати ML-моделі.

Секрети (URI БД, ключі S3) підхоплюються контейнерами через **External Secrets Operator**. Він раз на годину синхронізує дані з AWS Secrets Manager у Kubernetes secrets.

---

### 6.1 Приклад запиту та моделі даних

```http
POST /transaction HTTP/1.1
Content-Type: application/json

{
  "account_id": "ACC-123456",
  "amount": 250.75,
  "currency": "USD",          // опційно, за замовчуванням USD
  "transaction_type": "deposit", // deposit | withdraw | transfer
  "description": "Поповнення рахунку через банкомат"
}
```

* **В БД (PostgreSQL)** зʼявиться новий рядок у таблиці `transactions` з автоматичним `id`, `created_at` і `status='pending'`.
* **У Kafka** відправляється повідомлення у топік `banking.transactions`:

```json
{
  "action": "create",
  "data": {
    "id": 42,
    "account_id": "ACC-123456",
    "amount": 250.75,
    "currency": "USD",
    "transaction_type": "deposit",
    "description": "Поповнення рахунку через банкомат",
    "created_at": "2024-07-21T12:34:56Z",
    "status": "pending"
  }
}
```

Консюмер після накопичення batch формує файл (`transactions_2024-07-21-12-35-00.json`) і кладе його у `s3://<bucket>/archive/`. Airflow DAG реагує на появу файлу та оновлює агреговані таблиці.

---

## 7. Безпека

* VPC з приватними підмережами; доступ назовні - через VPC Endpoints.
* Усі S3-бакети з версіонуванням, шифруванням  і блокуванням публічного доступу.
* TLS між сервісами у кластері.
> Але звісно є обмеження пет проектом.


---

## 8. Моніторинг та логування (CloudWatch)

CloudWatch у цьому демо не піднімається автоматично — це дорого для домашнього проєкту. Але я показав, **як би це виглядало**:

* У `infra/dev/ec2.tf` залишив приклад `user_data`, який встановлює CloudWatch Agent. Його можна закоментувати / ввімкнути за потреби.
* IAM-роль `ec2_demo_role` має мінімальний набір прав (`logs:*` та `cloudwatch:PutMetricData`), які легко вимкнути.

Якщо все ж увімкнути агент, він би:

1. **Системні метрики**: CPU, RAM, диски. Агент шипить їх у CloudWatch Metrics з префіксом `DemoEc2/*`, щоб можна було будувати графіки та ставити аларми.
2. **Логи застосунку**: `/var/log/producer.log` та системні `/var/log/messages` стрімляться у CloudWatch Logs у групу `/demo/producer`. Завдяки цьому навіть у приватній підмережі можна дивитися логи через AWS Console.

> За замовчуванням логування вимкнено, щоб не генерувати зайві витрати. Якщо потрібно, достатньо розкоментувати секцію у `user_data` та залишити дозволи в ролі.

> У production-сценарії замість EC2 я б використав EKS DaemonSet з CloudWatch Agent, але тут достатньо знати, як це під’єднати.

---

#### Неактуальні (deprecated) команди

| Команда | Чому більше не потрібна |
|---------|------------------------|
| `make charts` | Збірка й публікація Helm-чартів тепер робиться автоматично в GitHub Actions (`.github/workflows/publish-helm-charts.yml`). Локально збирати нема сенсу. |
| `make deploy` | Раніше викликав `make charts`, зараз достатньо `kubectl apply -k ...` або чекати Flux-синк. Залишив історично, але краще не використовувати. |
| `build-consumer` | Було потрібно, коли ми вручну будували образ Kafka-consumer у Docker демона minikube. Тепер CI збирає multi-arch образ і пушить у GHCR, тому команда застаріла. |

> Я залишив ці цілі у Makefile для історії, але додав тег `deprecated` у коментарі. На продакшн (і навіть на демо) краще покладатися на CI/CD.

---

## 9. Що було складно

* **IAM policies**: легко дати забагато прав, тому сидів у документації, обрізав до мінімуму.
* **Kafka локально**: знайшов готовий Helm-chart, але довелося погратися з ресурсами, щоб запустилося в minikube.
* **External Secrets**: для EKS усе просто (роль + OIDC), а локально довелося зробити окремого юзера й зберегти ключі в секреті.

> Все таки мабуть навіть перестарався, та взяв завеликий розмах, але як результат за три дні праці вважаю дуже гарний, демонструє мої скіли в навчанні та мої минулі знання.

---

## 10. Які знання я демонструю цим проєктом

| Тема | Де видно у проєкті |
|------|--------------------|
| **IAM Basics** (користувачі, ролі, політики) | `infra/dev/iam_roles.tf`, модуль `modules/iam-role` |
| **Managed vs Inline policies** | використано managed-policies AWS + власні inline через `aws_iam_policy_document` |
| **Permission boundaries / SCP idea** | у ролі `terraform_infrastructure_role` задані обмеження через inline-policy як boundary |
| **Custom IAM-policy module** | `modules/iam-policy` приймає JSON-document і створює policy + attachment |
| **`aws_iam_policy_document`** | формується через Terraform, приклад у `infra/dev/s3.tf` для bucket-policy |
| **EC2 ↔ S3 доступ через IAM-роль** | роль `producer_transaction_role` додається в instance profile у `infra/dev/ec2.tf` |
| **AssumeRole всередині одного акаунту** | policy `sts:AssumeRole` у `iam_roles.tf` для External Secrets |
| **Кросс-аккаунт AssumeRole** | шаблон trust-policy з `Principal = 123456789012` у `modules/iam-role/main.tf` |
| **Condition по тегу / SourceVpce** | продемонстровано в bucket-policy S3 (`aws_iam_policy_document` з `Condition: aws:SourceVpce`) |
| **VPC Endpoints Gateway vs Interface** | `modules/vpc-endpoint` створює обидва типи; для S3 - Gateway, для Secrets Manager - Interface |
| **Чому іноді лише Interface** | S3 у приватній підмережі без Gateway - показано в `network.tf` з route через `vpce-*` |
| **VPC Peering та Transit Gateway** | `network.tf` містить приклад Peering; коментарі пояснюють плюси/мінуси TGW |
| **GitOps + Terraform workflow** | `Makefile`, GitHub Actions, Flux ─ демонстрація CI/CD та GitOps підходу |
| **Secrets Management** | External Secrets Operator + AWS Secrets Manager показують best-practice без plaintext |

---

### Детальніше про кожну IAM-роль і навіщо вона потрібна

| Роль | Навіщо вона існує | Де використовується |
|------|-------------------|---------------------|
| **terraform_infrastructure_role** | Дає самому Terraform мінімальні права створювати / оновлювати всі ресурси з коду. Носить тег `created-by=terraform` й обмежений регіоном, щоб випадково не розгорнутися десь ще. | Викликається при `terraform apply` через AWS CLI або GitHub Actions. |
| **airflow_etl_role** | Airflow повинен читати та писати дані у S3, тягнути креденшіали з Secrets Manager і складати логи у CloudWatch. Якщо змішати це з іншими правами — легко отримати «господаря всього». Тому окрема роль тільки для ETL. | Підключається у Helm-чарті Airflow через ServiceAccount + annotation `eks.amazonaws.com/role-arn`. |
| **producer_transaction_role** | REST-API (FastAPI) пише в Postgres і одночасно відправляє payload у Kafka та архівує «сирі» транзакції у S3 (`PutObject`). Логи не налаштовано — дорого для демо. | Додається до Pod-а Producer через IRSA (EKS) або InstanceProfile (EC2 demo). |
| **role_kafka_consumer** | Консюмер бере батчі з Kafka, читає (`GetObject`) і пише (`PutObject`) у S3 архів. | У Helm-чарті `kafka-consumer`. |
| **ec2_demo_role** | Дозволяє демо-інстансу (якщо запускати) встановити CloudWatch Agent і шипити базові метрики. Логи відправляти не обов’язково (дорого), дозволи можна вимкнути. | Instance Profile `ec2_profile`. |
| **external_secrets_role** | External Secrets Operator повинен читати певний префікс секретів (`dev/iwt/*`). Роль з таким scope і нічого зайвого. | Namespace `dev`, ресурс `AWSClusterSecretStore`.
| **iam_minikube_user** | Це виняток: у локальному minikube немає IRSA, тому довелося створити IAM User з access-keys і зберегти їх у локальний Secret. У production не використовується. | Лише в `local-cluster` для демо.

> Якщо розгортати цю платформу в production — усі ролі потрібні; IAM-User залишиться зайвим і може бути видалений.

---