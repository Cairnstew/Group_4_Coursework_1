# Group 4 – SE & DevOps Coursework 1

**Module:** Software Engineering and DevOps (MMI330704)  
**Institution:** Glasgow Caledonian University  
**Deadline:** Thursday 12th March 2026

---

## Overview

This repository contains the **Practical Component** of GCU SE & DevOps Coursework 1 (40 marks). It implements a Continuous Integration (CI) Pipeline that automates building, testing, and static code analysis of a Python project using **Jenkins** and **SonarQube**, deployed on an **AWS EC2** instance provisioned with **Terraform**.

The core application (`Dec2Hex.py`) converts decimal integers to hexadecimal — used as the subject of the CI pipeline demonstration.

---

## Repository Structure

```
Group_4_Coursework_1/
├── Dec2Hex.py                          # Main Python app (decimal to hex converter)
├── test_Dec2Hex.py                     # Unit tests (pytest)
├── jenkinsfile                         # Jenkins Pipeline definition
├── flake.nix                           # Nix flake for reproducible dev environment
├── flake.lock                          # Nix lockfile
├── .gitignore
├── LICENSE
│
├── scripts/
│   ├── connect.sh                      # SSH into the EC2 instance
│   ├── deploy.sh                       # Run terraform init/validate/apply
│   └── set-aws-creds.sh                # Helper to export AWS credentials
│
└── terraform/
    ├── main.tf                         # AWS provider, EC2 instance, security groups
    ├── terraform.tf                    # Terraform version/provider requirements
    ├── docker-compose.yaml             # Jenkins + SonarQube + PostgreSQL stack
    ├── .terraform.lock.hcl
    ├── jenkins/
    │   ├── Dockerfile                  # Custom Jenkins image (adds Python, plugins)
    │   └── casc.yaml                   # Jenkins Configuration as Code (JCasC)
    └── scripts/
        └── bootstrap.sh.tpl            # EC2 user-data: installs Docker, starts stack
```

---

## Infrastructure

The AWS infrastructure is fully defined in Terraform:

| Property       | Value                                             |
|----------------|---------------------------------------------------|
| Cloud          | AWS EC2                                           |
| Instance type  | `t2.large`                                        |
| OS             | Ubuntu (latest)                                   |
| Storage        | 25 GB gp3 (encrypted)                             |
| Ports open     | `8080` (Jenkins), `9000` (SonarQube), `22` (SSH)  |

On first boot, the EC2 instance runs `bootstrap.sh.tpl` which installs Docker, starts the full stack via Docker Compose, waits for SonarQube to be ready, generates a SonarQube token, and launches Jenkins with that token injected automatically.

---

## Getting Started

### Prerequisites

- AWS credentials configured (use `scripts/set-aws-creds.sh` if using AWS Academy)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.2
- An SSH key pair named `vockey` in AWS (or update `key_name` in `main.tf`)

### 1. Provision Infrastructure

```bash
bash scripts/deploy.sh
```

This runs `terraform init`, `terraform validate`, and `terraform apply` automatically. The public IP of the new instance is printed at the end as a ready-to-use SSH command.

### 2. SSH into the Instance

```bash
bash scripts/connect.sh <PUBLIC_IPV4_DNS>
```

Or set `PUBLIC_DNS` in a `.env` file in the repo root and run `bash scripts/connect.sh`.

---

## Accessing the Services

| Service    | URL                           | Default Credentials |
|------------|-------------------------------|---------------------|
| Jenkins    | `http://<your-ec2-ip>:8080`   | `admin` / `admin`   |
| SonarQube  | `http://<your-ec2-ip>:9000`   | `admin` / `admin`   |

To find your public IP:
```bash
curl -s http://checkip.amazonaws.com
```

---

## The Python Application

**File:** `Dec2Hex.py`

Implements decimal-to-hex conversion manually (without using Python's built-in `hex()`) with input validation and graceful error handling.

```bash
# Normal conversion
python3 Dec2Hex.py 255
# Output: Hexadecimal representation is: FF

# No argument
python3 Dec2Hex.py
# Output: Usage: python script.py <decimal_number>

# Invalid input
python3 Dec2Hex.py hello
# Output: Please provide a valid integer.
```

**Unit tests** (`test_Dec2Hex.py`) cover:

| Test | Input | Expected |
|------|-------|----------|
| `test_valid_integer` | `255` | `"FF"` |
| `test_valid_integer_16` | `16` | `"10"` |
| `test_zero` | `0` | `""` |
| `test_large_number` | `256` | `"100"` |

Run tests locally:
```bash
python3 -m pytest test_Dec2Hex.py -v
```

---

## CI Pipeline

The `jenkinsfile` defines a four-stage Jenkins Pipeline:

| Stage | What it does |
|-------|--------------|
| **Checkout** | Confirms workspace and branch, lists files |
| **SonarQube Analysis** | Runs static analysis and sends results to SonarQube at `localhost:9000` |
| **Run Dec2Hex** | Executes the script with valid input, no input, and invalid input to verify all code paths |
| **Unit Tests** | Runs `pytest test_Dec2Hex.py -v` |

The job is triggered automatically via **Poll SCM** every minute (`* * * * *`), so any push to `main` is picked up within a minute.

After a successful run, Jenkins prints a direct link to the SonarQube dashboard for the project.

---

## Docker Stack

The full CI environment runs in Docker Compose with three services:

- **Jenkins** — custom image built from `terraform/jenkins/Dockerfile`, pre-loaded with all required plugins and configured via JCasC (`casc.yaml`). No setup wizard required.
- **SonarQube** — `sonarqube:community` image, backed by PostgreSQL.
- **PostgreSQL** — database backend for SonarQube.

Jenkins configuration (users, credentials, SonarQube server URL) is managed entirely by `casc.yaml` — no manual UI setup needed.

---

## Nix Dev Shell

A reproducible development environment is provided via `flake.nix`, which pins Terraform 1.14, AWS CLI v2, and Packer.

```bash
nix develop
```

This ensures all contributors use the same tool versions regardless of their local setup.

---

## Coursework Task Status

| Task | Description | Marks | Status |
|------|-------------|-------|--------|
| Task 1 | Deploy EC2 (`t2.large`, Ubuntu, ports 8080/9000 open). Install Python, Git, and Jenkins. | 3 | ✅ |
| Task 2 | Configure Git, create remote GitHub repo, push `Dec2Hex.py`. | 3 | ✅ |
| Task 3a | Jenkins Freestyle Project — automatically detect changes to remote GitHub repo. | 2 | ✅ |
| Task 3b | Jenkins — compile the code. | 2 | ✅ |
| Task 3c | Jenkins — run the code with appropriate input values. | 2 | ✅ |
| Task 4 | Integrate SonarQube and SonarScanner for static code analysis. | 10 | ✅ |
| Task 5 | Extend `Dec2Hex.py` to handle missing and non-integer inputs. Add unit tests. Use version control to track changes. | 10 | ✅ |
| Task 6 | Ensure all test conditions pass and build succeeds. Address SonarQube feedback. Use version control to track changes. | 8 | ✅ |
| **Total** | | **40** | |

---

## License

This project is licensed under the [MIT License](LICENSE).