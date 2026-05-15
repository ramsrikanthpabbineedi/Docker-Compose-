# 🍽️ MyFoodMyLife — Dockerized Full-Stack App with CI/CD

A full-stack food ordering web application containerized with **Docker Compose** and deployed automatically to AWS EC2 via a **Jenkins CI/CD pipeline**. When a user places a food order, the owner receives an **email notification via AWS SNS** with the order details.

---

## 🏗️ Application Architecture

```
                        ┌─────────────────────────────────┐
                        │          AWS EC2 Instance        │
                        │                                  │
  User ──── HTTP:80 ───►│  ┌──────────────────────────┐   │
   (places order)       │  │  nginx (Reverse Proxy)    │   │
                        │  └────────────┬─────────────┘   │
                        │               │                  │
                        │  ┌────────────▼─────────────┐   │
                        │  │  backend (Node.js :5000)  │───┼──► AWS SNS
                        │  └────────────┬─────────────┘   │   (order email)
                        │               │                  │
                        │  ┌────────────▼─────────────┐   │
                        │  │  mongo (MongoDB :27017)   │   │
                        │  └──────────────────────────┘   │
                        │                                  │
                        └─────────────────────────────────┘
```

When a user submits a food order, the backend publishes the order details to an **AWS SNS topic** — the restaurant owner receives an **email** immediately with what was ordered.

---

## 📬 Order Notification Flow (AWS SNS)

The SNS topic is **provisioned by Terraform** and its ARN is passed to the backend via the `.env` file at deploy time.

```
User places order on website
        │
        ▼
Backend (Node.js) receives order via POST /api/orders
        │
        ▼
Order saved to MongoDB
        │
        ▼
Backend publishes to AWS SNS topic
  Subject : "🍽️ New Order Received!"
  Message : {
               customer : "John Doe",
               items     : ["Burger x2", "Fries x1", "Coke x2"],
               total     : "$18.50",
               address   : "123 Main St"
             }
        │
        ▼
SNS delivers email to subscribed owner
```

### Setting up order email alerts

The SNS topic is created automatically by Terraform. To receive order emails:

1. Go to **AWS Console → SNS → Topics**
2. Find the topic named `myfoodmylife-orders`
3. Click **Create subscription**
4. Protocol → **Email**
5. Endpoint → enter your email address
6. Click **Create subscription**
7. Open your inbox and click **Confirm subscription** in the AWS email

From that point, every food order placed on the website will send an email to that address instantly.

> 💡 You can add multiple email subscribers — useful if both the kitchen and the owner want order alerts.

---

## 🐳 Docker Compose Services

```yaml
services:
  nginx      # Reverse proxy + serves frontend  →  port 80
  backend    # Node.js / Express REST API       →  port 5000 (internal)
  mongo      # MongoDB 6.0 database             →  port 27017 (internal)
```

### Service dependency order

```
mongo (healthy) → backend (healthy) → nginx (starts)
```

Compose `depends_on` with `condition: service_healthy` ensures each service only starts after its dependency passes its healthcheck.

### Healthchecks

| Service | Healthcheck command |
|---|---|
| `mongo` | `mongosh --eval "db.adminCommand('ping')"` |
| `backend` | `wget -qO- http://localhost:5000/api/health` |

---

## 📁 Project Structure

```
.
├── app/
│   ├── backend/
│   │   ├── Dockerfile          # Node.js 18 Alpine image
│   │   ├── package.json
│   │   └── server.js           # Express API + SNS order notifications
│   ├── frontend/
│   │   ├── Dockerfile          # Nginx Alpine image
│   │   └── index.html          # Static frontend / order form
│   ├── nginx/
│   │   └── nginx.conf          # Reverse proxy config
│   ├── docker-compose.yml      # Orchestrates all 3 services
│   └── .env                    # ⚠️ Generated at deploy time — never committed
├── terraform/                  # Provisions AWS EC2 + SNS topic
├── ansible/                    # Installs tooling on Jenkins host
└── Jenkinsfile                 # Full CI/CD pipeline definition
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Containerisation | Docker + Docker Compose |
| Container Registry | DockerHub |
| Reverse Proxy | Nginx (Alpine) |
| Backend | Node.js 18 + Express |
| Database | MongoDB 6.0 |
| Order Notifications | AWS SNS (email) |
| CI/CD | Jenkins |
| Infrastructure | Terraform (AWS EC2 + SNS) |
| Configuration | Ansible |
| Cloud | AWS (eu-north-1) |

---

## 🚀 CI/CD Pipeline

Every push to `main` triggers the Jenkins pipeline:

```
Git Clone
    │
    ▼
Terraform Init → Plan → Apply
(provisions EC2 + SNS topic for order notifications)
    │
    ▼
Wait for EC2 (status checks + SSH ready)
    │
    ▼
Ansible Ping + Configure
    │
    ▼
Docker Build
  ├── ramsrikanthp/myfoodmylife-backend:latest
  └── ramsrikanthp/myfoodmylife-frontend:latest
    │
    ▼
Docker Push → DockerHub
    │
    ▼
Setup EC2 (install Docker + Compose plugin)
    │
    ▼
Deploy to EC2
  ├── scp docker-compose.yml
  ├── scp .env  ← includes AWS_SNS_TOPIC_ARN from Terraform output
  ├── scp nginx/nginx.conf
  └── docker compose pull && docker compose up -d
    │
    ▼
Health Check (polls ALB URL up to 5 min)
    │
    ▼
Pipeline SNS Notification (✅ deploy success / ❌ deploy failure)
```

---

## 🔐 Environment Variables (.env)

The `.env` file is **never committed to git**. It is generated dynamically by Jenkins at deploy time from stored credentials and the SNS ARN captured from Terraform output:

```env
PORT=5000
MONGO_URI=mongodb://mongo:27017/myfoodmylife

# AWS config — used by backend to publish order notifications to SNS
AWS_REGION=eu-north-1
AWS_ACCESS_KEY_ID=<injected from Jenkins>
AWS_SECRET_ACCESS_KEY=<injected from Jenkins>
AWS_SNS_TOPIC_ARN=<captured from Terraform output>
```

The `AWS_SNS_TOPIC_ARN` is automatically captured from `terraform output -raw sns_topic_arn` after `terraform apply` and injected into `.env` — no manual copy-paste needed.

After deployment the `.env` file is deleted from the Jenkins workspace:
```bash
rm -f app/.env
```

---

## 🖥️ Run Locally with Docker Compose

### Prerequisites
- Docker Desktop installed and running
- AWS account with SNS topic created (for order email alerts)

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/ramsrikanthpabbineedi/Docker-Compose-.git
cd Docker-Compose-/app

# 2. Create your .env file
cat > .env << EOF
PORT=5000
MONGO_URI=mongodb://mongo:27017/myfoodmylife
AWS_REGION=eu-north-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_SNS_TOPIC_ARN=arn:aws:sns:eu-north-1:123456789012:myfoodmylife-orders
EOF

# 3. Build and start all containers
docker compose up --build

# 4. Open in browser
# http://localhost
```

### Useful Docker Compose commands

```bash
# Start in background
docker compose up -d

# View running containers and health status
docker compose ps

# View logs (all services)
docker compose logs -f

# View backend logs (SNS publish logs appear here)
docker compose logs -f backend

# Stop all containers
docker compose down

# Stop and remove volumes (wipes MongoDB data)
docker compose down -v

# Rebuild a single service after code change
docker compose build backend
docker compose up -d backend
```

---

## 🐳 DockerHub Images

| Service | Image |
|---|---|
| Backend | `ramsrikanthp/myfoodmylife-backend:latest` |
| Frontend | `ramsrikanthp/myfoodmylife-frontend:latest` |

Pull and run directly without building:
```bash
docker compose pull
docker compose up -d
```

---

## 🔑 Jenkins Credentials Setup

Add these at **Jenkins → Manage Jenkins → Credentials** before running the pipeline:

| Credential ID | Type | Used for |
|---|---|---|
| `aws_id` | AWS Credentials | Terraform + AWS CLI |
| `aws-account-id` | Secret text | AWS account ID |
| `github-pat` | Username/Password | Git clone |
| `dockerhub-creds` | Username/Password | Docker push/pull |
| `app-server-ssh` | SSH Private Key | SSH + SCP to EC2 |

---

## 🩺 Health Check

After deployment the pipeline polls the application URL up to **30 times** (every 10 seconds = 5 minutes max). It accepts HTTP `200`, `301`, or `302` as healthy responses.

Check container health manually on EC2:
```bash
docker compose ps
docker compose logs nginx
docker compose logs backend
```

---

## 🧹 Teardown

```bash
# Destroy all AWS infrastructure (EC2 + SNS topic)
cd terraform
terraform destroy -auto-approve
```

> ⚠️ This terminates the EC2 instance and **deletes the SNS topic** — order email notifications will stop. All running containers and MongoDB data will be lost.

---

## 📝 License

MIT
