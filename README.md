# HireSignal ⚡

> A real-time AI-powered job matching platform built with microservices architecture.
> Built to learn. Built to scale. Built to ship.

---

## What is this?

HireSignal is a distributed job board where candidates get matched to jobs using AI embeddings, events flow through Kafka, and every service is independently deployable. It's not a tutorial project — it's a production-grade system built from scratch to understand how real systems work.

---

## Architecture at a glance

```
React / Angular
      │
      ▼
 API Gateway                     (coming Phase 2)
      │
 ┌────┴──────────────────────────────────────┐
 │                                           │
auth-service    job-service    user-service    notification-service
  :8081           :8082          :8083              :8084
   │               │               │                   │
   │           [Kafka] ────────────────────────────────┘
   │               │
auth_db         job_db          user_db
   └──────────────┴───────────────┘
              PostgreSQL :5432
```

Every service owns its database. No service queries another's DB directly. Cross-service communication happens through REST APIs or Kafka events only.

---

## Tech stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Backend | Java 17 + Spring Boot 3.2 | Industry standard, battle-tested |
| Build | Gradle multi-module | One command builds all services |
| Auth | Spring Security + JWT | Stateless auth, scales horizontally |
| Database | PostgreSQL 16 | Reliable, ACID, great for relational data |
| Cache | Redis 7 | Sub-millisecond reads, session storage |
| Events | Apache Kafka | Decoupled async communication |
| Search | Elasticsearch 8 | Full-text search with filters |
| Logging | ELK Stack | Centralised logs across all services |
| Frontend | React + Angular | Two frontends, same API |
| CI/CD | Jenkins + Docker | Reproducible builds, consistent deploys |
| Cloud | AWS EC2 | (Phase 3) |

---

## Prerequisites

Install these before anything else. No exceptions.

| Tool | Version | Download |
|------|---------|----------|
| Java JDK | 17+ | https://www.oracle.com/java/technologies/javase/jdk21-archive-downloads.html |
| Docker Desktop | Latest | https://www.docker.com/products/docker-desktop |
| IntelliJ IDEA | Any | https://www.jetbrains.com/idea |
| Node.js + npm | 18+ | https://nodejs.org |
| Git | Any | https://git-scm.com |
| Gradle | 8.5 | https://gradle.org/releases/ |

Verify your installs:

```bash
java -version        # should show 17+
docker --version     # should show 24+
docker compose version
node --version       # should show 18+
git --version
```

If any of these fail — fix them before continuing. Everything below depends on them.

---

## First-time setup

### 1. Clone the repo

```bash
git clone https://github.com/your-org/hiresignal.git
cd hiresignal
```

### 2. Start infrastructure

All databases, message brokers, and tooling run in Docker. You never install PostgreSQL or Kafka directly on your machine.

```bash
# Start Phase 1 infrastructure (what you need for auth + job services)
docker compose up -d postgres redis zookeeper kafka kafka-ui pgadmin

# Verify everything is running — all should show "running" or "healthy"
docker compose ps
```

**First run takes 3-5 minutes** — Docker pulls images. Subsequent starts are instant.

### 3. Verify databases exist

```bash
docker exec -it postgres psql -U hiresignal -d postgres -c "\l"
```

You should see `auth_db`, `job_db`, `user_db` listed. If not, see [Troubleshooting](#troubleshooting).

### 4. Build the project

```bash
# Windows
.\gradlew build

# Mac / Linux
./gradlew build
```

Expected output: `BUILD SUCCESSFUL`. If you see errors, paste them in the team Slack channel with the full output.

### 5. Run a service

Open a separate terminal for each service you want to run:

```bash
# Terminal 1
./gradlew :auth-service:bootRun

# Terminal 2
./gradlew :job-service:bootRun

# Terminal 3 (when needed)
./gradlew :user-service:bootRun
```

### 6. Verify auth service is alive

```bash
curl http://localhost:8081/api/auth/health
# Expected: auth-service is running
```

---

## Local service ports

| Service | Port | Notes |
|---------|------|-------|
| auth-service | 8081 | JWT auth, registration, login |
| job-service | 8082 | Job CRUD + Kafka producer |
| user-service | 8083 | Candidate/recruiter profiles |
| notification-service | 8084 | Kafka consumer → alerts |
| api-gateway | 8080 | Phase 2 — not yet built |

---

## Infrastructure dashboards

| Tool | URL | Credentials |
|------|-----|-------------|
| pgAdmin (PostgreSQL UI) | http://localhost:5050 | admin@hiresignal.com / admin123 |
| Kafka UI | http://localhost:8090 | No login required |
| Kibana (logs) | http://localhost:5601 | No login required |
| Elasticsearch | http://localhost:9200 | No login required |

### Connecting pgAdmin to PostgreSQL

First time only:

1. Open http://localhost:5050
2. Login: `admin@hiresignal.com` / `admin123`
3. Left panel → right-click **Servers** → **Register** → **Server**
4. **General tab** → Name: `HireSignal Local`
5. **Connection tab:**
   - Host: `host.docker.internal`
   - Port: `5432`
   - Database: `postgres`
   - Username: `hiresignal`
   - Password: `hiresignal123`
6. Save

---

## Quick API test

Register a user:

```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@test.com","password":"password123","role":"CANDIDATE"}'
```

Login:

```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@test.com","password":"password123"}'
```

Both should return a JSON object with `accessToken` and `refreshToken`.

Copy the `accessToken` and use it on protected endpoints:

```bash
curl http://localhost:8082/api/jobs \
  -H "Authorization: Bearer <paste-token-here>"
```

---

## Project structure

```
hiresignal/
│
├── build.gradle              # Root: shared Spring Boot version + common deps
├── settings.gradle           # Registers all modules — add new services here
├── docker-compose.yml        # All infrastructure
│
├── infra/
│   └── postgres/
│       └── init.sql          # Creates databases on first container start
│
├── common/                   # Shared DTOs used across services
│   └── src/main/java/com/hiresignal/common/
│
├── auth-service/             # Port 8081
├── job-service/              # Port 8082
├── user-service/             # Port 8083
└── notification-service/     # Port 8084
```

Each service follows the same internal layout:

```
<service>/
├── build.gradle
└── src/main/
    ├── java/com/hiresignal/<service>/
    │   ├── <Service>Application.java   ← entry point
    │   ├── config/                     ← Spring configs
    │   ├── controller/                 ← REST endpoints
    │   ├── entity/                     ← JPA entities → DB tables
    │   ├── repository/                 ← DB queries (Spring Data)
    │   └── service/                    ← business logic
    └── resources/
        └── application.yml            ← port, DB url, secrets
```

---

## Adding a new microservice

Follow every step. Don't skip any.

**Step 1 — Create folders**

```bash
# Replace 'myservice' with your service name
mkdir -p myservice/src/main/java/com/hiresignal/myservice
mkdir -p myservice/src/main/resources
mkdir -p myservice/src/test/java
```

**Step 2 — Register in `settings.gradle`**

```groovy
include 'myservice'   // add this line
```

**Step 3 — Create `myservice/build.gradle`**

```groovy
plugins {
    id 'org.springframework.boot'
}

dependencies {
    implementation project(':common')
    implementation 'org.springframework.boot:spring-boot-starter-web'
    // add your deps here
}
```

**Step 4 — Create main class**

```java
package com.hiresignal.myservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MyServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyServiceApplication.class, args);
    }
}
```

**Step 5 — Create `application.yml`**

```yaml
spring:
  application:
    name: my-service

server:
  port: 808X   # pick a unique port — check the ports table above

logging:
  level:
    com.hiresignal: DEBUG
```

**Step 6 — Build and verify**

```bash
./gradlew build
# Must show BUILD SUCCESSFUL
```

---

## Common commands

```bash
# Build everything
./gradlew build

# Build + skip tests (faster)
./gradlew build -x test

# Build single service
./gradlew :auth-service:build

# Clean build (fixes weird cache issues)
./gradlew clean build

# Run single service
./gradlew :auth-service:bootRun

# Start all Docker infra
docker compose up -d

# Stop all Docker infra (data kept)
docker compose down

# Nuclear reset — stops everything and deletes all data
docker compose down -v

# Check container health
docker compose ps

# Tail logs for a container
docker compose logs -f kafka

# Connect to Postgres directly
docker exec -it postgres psql -U hiresignal -d auth_db

# List Kafka topics
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list

# Watch Kafka messages in real time
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic job.posted \
  --from-beginning
```

---

## Troubleshooting

**`BUILD FAILED` — Main class not found**

You have a `build.gradle` with the Spring Boot plugin but no `main()` class yet. Create the `Application.java` entry point first.

**`Connection refused` on startup**

Docker isn't running or the container isn't healthy. Run `docker compose ps` — everything must show `running` or `healthy`. If a container shows `restarting`, run `docker compose logs <container-name>` and paste in Slack.

**pgAdmin — password authentication failed**

Use `host.docker.internal` as the host, not `postgres`. pgAdmin runs inside Docker and needs to reach PostgreSQL through the host network on Docker Desktop for Windows/Mac.

**Kafka consumer not receiving messages**

Check `auto-offset-reset: earliest` is set in the consumer's `application.yml`. Without this, a consumer only sees messages published after it first connects.

**Port already in use**

Something else is using that port. Find and kill it:

```bash
# Windows
netstat -ano | findstr :8081
taskkill /PID <pid> /F
```

**Tables not created**

Check `spring.jpa.hibernate.ddl-auto: update` is set in `application.yml`. Also verify the service started without errors — a failed startup won't create tables even with `update`.

---

## Development workflow

This is how we work. Follow it or your PRs will be sent back.

1. **Pull latest** before starting anything — `git pull origin main`
2. **Create a branch** — `git checkout -b feat/your-feature-name`
3. **Run infrastructure** — `docker compose up -d postgres redis zookeeper kafka kafka-ui`
4. **Make your changes** — one concern per commit
5. **Build before pushing** — `./gradlew build` must pass
6. **Write a clear commit message** — `feat: add job search endpoint with filters`
7. **Open a PR** — describe what changed and why, not how

Commit message format:

```
feat:     new feature
fix:      bug fix
refactor: code change that doesn't add a feature or fix a bug
docs:     documentation only
test:     adding or fixing tests
chore:    build config, deps, tooling
```

---

## Environment overview

| Environment | How to run | DB | Notes |
|-------------|-----------|-----|-------|
| Local | `./gradlew :service:bootRun` | Docker PostgreSQL | `ddl-auto: update` |
| Staging | Jenkins pipeline | AWS RDS | `ddl-auto: validate` |
| Production | Jenkins pipeline | AWS RDS | `ddl-auto: none` + Flyway |

Never run with `ddl-auto: create` or `create-drop` outside of unit tests. It drops your tables.

---

## Questions?
- Want to add a new service → follow the checklist above, then open a PR

---

*HireSignal — built by engineers, for engineers.*
