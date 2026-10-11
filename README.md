# DevOps Kursrepo – YH Utbildning

Detta repository används under min yrkeshögskoleutbildning (YH) i kursen **DevOps utveckling**.

Projektet byggs upp steg för steg vecka för vecka genom praktiska moduler – från grundläggande arbetssätt, versionshantering och CI/CD-pipelines till molndriftsättning i Azure, infrastruktur som kod (IaC), containrar och observerbarhet.

---

## 📚 Kursmoduler & Progress

| Modul | Område | Status / Innehåll |
|:---:|---|---|
| **01** | **DevOps som arbetssätt** | Klar – Värdeflödeskarta (VSM), flaskhalsanalys och DORA-mått ([docs/01-delivery-analysis.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/01-delivery-analysis.md)) |
| **02** | **Versionshantering** | Klar – Trunk-based development, PR-mall, CODEOWNERS, SemVer och releasetagg `v0.1.0` ([docs/02-branching-strategy.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/02-branching-strategy.md)) |
| **03** | **Kontinuerlig integration (CI)** | Klar – GitHub Actions pipeline, lokala bygg-/testskript, commit-validering och kvalitetsgrindar ([docs/03-ci-pipeline.md](file:///Users/raffimedz/Desktop/devops/devops-repo/docs/03-ci-pipeline.md)) |
| **04** | **Azure App Service** | Kommande |
| **05** | **CI/CD till Azure** | Kommande |
| **06** | **Bicep (IaC)** | Kommande |
| **07** | **Containrar** | Kommande |
| **08** | **Observerbarhet** | Kommande |
| **09** | **Container Apps** | Kommande |
| **10** | **Säkerhet** | Kommande |
| **11** | **Incidenthantering** | Kommande |
| **12** | **Förbättring och redovisning** | Kommande |

---

## 🛠 Repots struktur & verktyg

```text
devops-repo/
├── .github/
│   ├── workflows/
│   │   └── build-test-pipeline.yml # CI-pipeline som körs vid push/PR mot main
│   ├── CODEOWNERS                  # Automatisk tilldelning av granskare
│   └── pull_request_template.md    # Mall för Pull Requests med kvalitetsfrågor
├── docs/                           # Kursdokumentation och modulrapporter
├── scripts/
│   ├── build.sh                    # Bygg- och strukturkontroll (körs lokalt & i CI)
│   ├── test.sh                     # Funktionella och strukturella tester
│   └── check-commit-messages.sh    # Validerar Conventional Commits
└── README.md
```

---

## 🚀 Köra skripten lokalt

Innan du pushar eller öppnar en Pull Request kan du köra testerna lokalt i terminalen:

```bash
# Kör byggkontrollen
./scripts/build.sh

# Kör testsviten
./scripts/test.sh

# Validera dina senaste commit-meddelanden
./scripts/check-commit-messages.sh
```
