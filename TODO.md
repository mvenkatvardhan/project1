# Your hands-on roadmap: Jenkins CI/CD for Node.js

Work through this top to bottom. Don't skip ahead — each phase depends on the
one before it actually working. Check boxes as you go.

---

## Phase 0 — Get your tools installed (do this first, once)

- [ ] Install Git → `git --version` should print something
- [ ] Install Node.js (v20) → `node --version` and `npm --version`
- [ ] Install Docker Desktop (or Docker Engine on Linux) → `docker --version`
- [ ] Create a free GitHub account (if you don't have one)
- [ ] Create a free Docker Hub account (if you don't have one) — you'll push images here

**Checkpoint:** you can run `git`, `node`, `npm`, and `docker` from your terminal without errors.

---

## Phase 1 — Get the app running on your own machine

- [ ] Download the project files I gave you into a folder, e.g. `nodejs-cicd-project/`
- [ ] Open a terminal in that folder
- [ ] Run `npm install`
- [ ] Run `npm test` — you should see tests pass (2 tests)
- [ ] Run `npm start`
- [ ] Open a browser to `http://localhost:3000` — you should see the JSON welcome message
- [ ] Open `http://localhost:3000/health` — you should see `{"status":"UP"}`
- [ ] Stop the server (Ctrl+C)

**Checkpoint:** the app runs on your laptop and both routes respond. If this doesn't work, nothing downstream will — fix this first.

---

## Phase 2 — Put the code on GitHub

- [ ] Create a new **empty** repository on GitHub (no README, no .gitignore — just empty)
- [ ] In your project folder, run:
  ```bash
  git init
  git add .
  git commit -m "Initial commit: Node.js app with Jenkins pipeline"
  git branch -M main
  git remote add origin https://github.com/<your-username>/<repo-name>.git
  git push -u origin main
  ```
- [ ] Refresh the GitHub page — confirm all your files (including `Jenkinsfile`) are there

**Checkpoint:** your repo on GitHub shows `Jenkinsfile`, `Dockerfile`, `src/`, `test/`, `package.json`.

---

## Phase 3 — Get Jenkins running

- [ ] Run Jenkins in Docker so it can also control Docker on your machine:
  ```bash
  docker run -d --name jenkins -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    jenkins/jenkins:lts
  ```
- [ ] Open `http://localhost:8080`
- [ ] Unlock Jenkins using the initial admin password:
  ```bash
  docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
  ```
- [ ] Choose "Install suggested plugins"
- [ ] Create your admin user

**Checkpoint:** you can log into the Jenkins dashboard at `localhost:8080`.

---

## Phase 4 — Install the plugins the pipeline needs

Manage Jenkins → Plugins → Available plugins → search and install each:

- [ ] NodeJS Plugin
- [ ] SonarQube Scanner
- [ ] OWASP Dependency-Check Plugin
- [ ] Docker Pipeline
- [ ] Restart Jenkins after installing (checkbox is usually offered automatically)

**Checkpoint:** all four show up under Manage Jenkins → Plugins → Installed.

---

## Phase 5 — Configure tools in Jenkins

Manage Jenkins → Tools:

- [ ] Add a **NodeJS** installation named exactly `NodeJS-20`, version 20.x
- [ ] Add an **OWASP Dependency-Check** installation named exactly `OWASP-DepCheck-10`

(These names must match what's written in the Jenkinsfile — that's how Jenkins knows which tool to use.)

**Checkpoint:** both tools are saved without errors.

---

## Phase 6 — Get SonarQube running

- [ ] Run SonarQube locally:
  ```bash
  docker run -d --name sonarqube -p 9000:9000 sonarqube:lts-community
  ```
- [ ] Wait ~1 minute, then open `http://localhost:9000`
- [ ] Log in with default credentials `admin` / `admin`, set a new password
- [ ] Create a project manually (or let the pipeline auto-create it) and generate a **token** (My Account → Security → Generate Token)
- [ ] In Jenkins: Manage Jenkins → System → SonarQube servers → add one named `MySonarQubeServer`, paste the server URL (`http://host.docker.internal:9000` if Jenkins is also in Docker) and the token as credentials

**Checkpoint:** Jenkins and SonarQube can "see" each other — you'll fully confirm this in Phase 9's first run.

---

## Phase 7 — Install Trivy on the Jenkins agent

Trivy is run as a plain shell command in the pipeline, so it must exist inside the Jenkins container:

- [ ] Shell into the Jenkins container: `docker exec -it -u root jenkins bash`
- [ ] Install Trivy (Debian-based, matches the Jenkins LTS image):
  ```bash
  apt-get update && apt-get install -y wget apt-transport-https gnupg lsb-release
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
  echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
  apt-get update && apt-get install -y trivy
  ```
- [ ] Exit the container, confirm: `docker exec jenkins trivy --version`

**Checkpoint:** `trivy --version` prints a version number.

---

## Phase 8 — Add your Docker Hub credentials to Jenkins

- [ ] Manage Jenkins → Credentials → System → Global credentials → Add Credentials
- [ ] Kind: "Username with password", enter your Docker Hub username/password
- [ ] Set the **ID** field to exactly `dockerhub-creds` (matches the Jenkinsfile)

**Checkpoint:** the credential appears in the list.

---

## Phase 9 — Create and run the pipeline job

- [ ] Jenkins dashboard → New Item → name it `nodejs-cicd-demo` → type "Pipeline" → OK
- [ ] Under "Pipeline" section: choose "Pipeline script from SCM"
- [ ] SCM: Git → paste your GitHub repo URL → branch `*/main`
- [ ] Script Path: `Jenkinsfile` (default, just confirm it)
- [ ] Save
- [ ] Also edit `DOCKER_IMAGE` at the top of your Jenkinsfile to use **your own** Docker Hub username instead of `yourdockerhubuser`, commit, and push
- [ ] Click "Build Now"
- [ ] Click into the running build → "Console Output" and watch it move through each stage live

**Checkpoint:** don't expect this to go green on the first try — see Phase 10.

---

## Phase 10 — Debug it (this is where the real learning happens)

Pipelines almost never work perfectly first try. Work through failures stage by stage:

- [ ] If it fails at **Checkout** → check the repo URL/branch in the job config
- [ ] If it fails at **Install Dependencies** → check the NodeJS tool name matches `NodeJS-20`
- [ ] If it fails at **SonarQube Analysis** → check the server name/URL/token in Manage Jenkins → System
- [ ] If it fails at **Quality Gate** (timeout) → you likely need a webhook from SonarQube back to Jenkins: SonarQube → Administration → Webhooks → add `http://<jenkins-url>/sonarqube-webhook/`
- [ ] If it fails at **OWASP Dependency-Check** → the first run downloads the entire NVD database and can take 10–20+ minutes — be patient, it's not stuck
- [ ] If it fails at **Docker Build/Trivy/Push** → confirm the Jenkins container can reach the Docker daemon (the `-v /var/run/docker.sock` mount from Phase 3) and that `dockerhub-creds` is correct

**Checkpoint:** you fixed at least one real failure yourself. That's the skill, not the green checkmark.

---

## Phase 11 — Get a fully green pipeline

- [ ] Re-run "Build Now" after each fix until every stage is green
- [ ] Confirm the image appears in your Docker Hub account
- [ ] Run `curl http://localhost:3000/health` on the Jenkins host and see `{"status":"UP"}` from the deployed container

**Checkpoint:** an actual container, built by Jenkins, is running and responding.

---

## Phase 12 — Prove you understand it (do this even if no one's checking)

- [ ] Deliberately break a test in `test/app.test.js`, push it, watch the pipeline fail at Unit Tests and stop — don't let it reach Deploy
- [ ] Deliberately add a known-vulnerable old dependency version to `package.json`, push it, watch OWASP Dependency-Check catch it
- [ ] Write 3–4 sentences in your own words explaining what each of SonarQube, OWASP Dependency-Check, and Trivy actually scans differently

**Checkpoint:** you can explain this pipeline out loud without looking at notes.

---

## Where to start right now

Begin at **Phase 0**. Come back and tell me when you've got Phase 1 working (app running locally) — that's the real foundation. Don't jump to Jenkins before that works.
