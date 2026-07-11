# Jenkins CI/CD Pipeline for a Node.js Application — Project Report

## 1. What this project actually is

A working Node.js app + a Jenkins pipeline that, on every commit, automatically:

1. Pulls the code
2. Installs dependencies
3. Runs unit tests
4. Runs static code analysis (SonarQube)
5. Scans open-source dependencies for known vulnerabilities (OWASP Dependency-Check)
6. Builds a Docker image
7. Scans that image for OS/package vulnerabilities (Trivy)
8. Pushes the image to a registry
9. Deploys the container

This README explains, stage by stage, what really happens under the hood, what each file does, and how to set it all up on a real (or local/free-tier) Jenkins server — so you can reproduce it yourself and genuinely be able to explain it in an interview, not just recite the resume bullet.

## 2. File-by-file breakdown

| File | Purpose |
|---|---|
| `src/app.js` | The Express app itself — a `/` route and a `/health` route used by Docker's HEALTHCHECK. |
| `test/app.test.js` | Jest + Supertest unit tests. This is what the "Unit Tests" pipeline stage runs. |
| `package.json` | Declares dependencies and the `npm test` script Jenkins calls. |
| `Dockerfile` | Multi-stage build: stage 1 installs prod dependencies, stage 2 copies only what's needed into a minimal `node:20-alpine` image, running as a non-root user. Smaller image + non-root user = fewer things for Trivy to flag. |
| `.dockerignore` | Keeps `node_modules`, tests, and reports out of the Docker build context. |
| `sonar-project.properties` | Tells the SonarScanner CLI where your source/test folders and coverage report are. |
| `Jenkinsfile` | The pipeline definition itself — this is what you paste into a Jenkins "Pipeline" job, pointing at your Git repo. |

## 3. What actually happens at each stage

**Checkout** — Jenkins clones your Git repository at the commit that triggered the build (via a webhook or polling).

**Install Dependencies (`npm ci`)** — `npm ci` (not `npm install`) is used because it installs exact versions from `package-lock.json`, which is what you want in CI: reproducible builds, no surprise version drift.

**Unit Tests (`npm test`)** — Runs Jest, which also generates a coverage report (`coverage/lcov.info`). That coverage file is consumed by the next stage.

**SonarQube Analysis** — The `sonar-scanner` CLI walks your source code and sends metrics to a SonarQube server: code smells, duplication, cyclomatic complexity, security hotspots (e.g. use of `eval`, hardcoded secrets, SQL string concatenation), and test coverage (pulled from the lcov file). This is genuinely static analysis — no code is executed.

**Quality Gate** — SonarQube evaluates your analysis against a threshold (e.g. "no new critical bugs", "coverage ≥ 80%") and calls back to Jenkins via a webhook. `waitForQualityGate abortPipeline: true` means the whole pipeline fails here if the gate isn't met — this is the actual enforcement mechanism, not just a report you can ignore.

**OWASP Dependency-Check** — This is different from SonarQube: it doesn't read your code, it reads your **dependency tree** (`package-lock.json`) and cross-references every library + version against the National Vulnerability Database (NVD) for known CVEs. This is what actually catches "you're using an old version of `lodash` with a known prototype-pollution vulnerability."

**Docker Build** — Builds the image from the multi-stage `Dockerfile`, tagged with the Jenkins build number so every build produces a traceable, immutable artifact.

**Trivy Image Scan** — Scans the *built image*, not your source code: OS packages inside the `alpine` base layer, plus the Node.js dependencies baked into the image. `--exit-code 1` on HIGH/CRITICAL findings means the pipeline stops the release rather than shipping a vulnerable image — this is the actual "reduced vulnerabilities" mechanism, not a cosmetic report.

**Push to Registry** — Only reached if every prior gate passed. Pushes the tagged image to Docker Hub (or ECR/GCR/ACR in a real setup).

**Deploy** — Stops any existing container and runs the new image. In this demo it's a plain `docker run`; in production you'd swap this for `kubectl apply`, an ECS service update, or a docker-compose pull+up on the target host.

## 4. How to actually set this up (step by step)

1. **Get a Jenkins instance.** Easiest for learning: run it in Docker.
   ```bash
   docker run -d --name jenkins -p 8080:8080 -p 50000:50000 \
     -v jenkins_home:/var/jenkins_home \
     -v /var/run/docker.sock:/var/run/docker.sock \
     jenkins/jenkins:lts
   ```
2. **Install plugins**: NodeJS, SonarQube Scanner, OWASP Dependency-Check, Docker Pipeline, Pipeline: Stage View.
3. **Configure tools** (Manage Jenkins → Tools): add a NodeJS 20 installation, an OWASP Dependency-Check installation.
4. **Run SonarQube.** Easiest: `docker run -d -p 9000:9000 sonarqube:lts-community`. Log in, generate a project token, add the server URL + token in Manage Jenkins → System → SonarQube servers, matching the `SONARQUBE_ENV` name in the Jenkinsfile.
5. **Install Trivy on the Jenkins agent** (`apt install trivy` or the official install script) since it's invoked as a shell command, not a plugin.
6. **Add credentials**: a Docker Hub username/password credential in Jenkins with the ID `dockerhub-creds` (matches the Jenkinsfile).
7. **Create the pipeline job**: New Item → Pipeline → "Pipeline script from SCM" → point it at your Git repo containing this project and the `Jenkinsfile`.
8. **Add a webhook** on your Git repo (GitHub/GitLab) pointing at your Jenkins URL so pushes trigger builds automatically.
9. **Push a commit** and watch the Stage View — each box in the diagram above should light up green in order.

## 5. About the metrics in your original write-up

"Reduced vulnerabilities by 40%" and "improved deployment success rate by 25%" are the kind of numbers you should generate yourself once this is running, not copy as-is: run Dependency-Check/Trivy once before you had any scanning, note the vulnerability count, then again after a few iterations of fixing flagged issues, and report the real delta. Same for deployment success rate — track your last N manual deploys vs. N pipeline-automated deploys. That turns the resume line into something you can back up with an actual before/after screenshot in an interview, which is far more convincing than the percentage alone.

## 6. Suggested next steps to go deeper

- Add a `docker-compose.yml` that spins up Jenkins + SonarQube together for local dev.
- Add Slack/email notifications on pipeline failure (`post { failure { ... } }`).
- Move from `docker run` to deploying onto a local `kind`/`minikube` Kubernetes cluster for a more realistic "Deploy" stage.
- Add branch-based logic (only deploy from `main`, run tests on every PR).
