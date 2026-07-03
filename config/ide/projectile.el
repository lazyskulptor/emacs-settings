;;; projectile.el --- Projectile configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Projectile 프로젝트 관리 설정

;;; Code:

(use-package projectile
  :ensure t
  :init
  (projectile-mode +1)
  :bind (:map projectile-mode-map
              ("s-p" . projectile-command-map)
              ("C-c p" . projectile-command-map)))

(use-package deadgrep
  :ensure t
  :after projectile)

(projectile-register-project-type 'maven '("pom.xml")
                                  :project-file "pom.xml"
                                  :compile "./mvnw -B clean install"
                                  :test "./mvnw -B test"
                                  :run "./mvnw spring-boot:run"
                                  :test-suffix "Tests")

(projectile-register-project-type 'gradle '("build.gradle")
                                  :project-file "build.gradle"
                                  :compile "./gradlew build"
                                  :test "./gradlew test"
                                  :run "./gradlew bootRun"
                                  :src-dir "src/main/java"
                                  :test-dir "src/test/java"
                                  :test-suffix "Tests")

(projectile-register-project-type 'npm '("package.json")
                                  :project-file "package.json"
                                  :src-dir "src/"
                                  :test-dir "__tests__/"
                                  :test-suffix ".spec")

(projectile-register-project-type 'go '("go.mod")
                                  :project-file "go.mod"
                                  :compile "go build ./..."
                                  :test "go test ./..."
                                  :run "go run ."
                                  :test-suffix "_test")

(projectile-register-project-type 'clojure-lein '("project.clj")
                                  :project-file "project.clj"
                                  :compile "lein compile"
                                  :test "lein test"
                                  :run "lein run"
                                  :test-suffix "_test")

(projectile-register-project-type 'clojure-deps '("deps.edn")
                                  :project-file "deps.edn"
                                  :compile "clj -M:compile"
                                  :test "clj -M:test"
                                  :run "clj -M:run"
                                  :test-suffix "_test")

(projectile-register-project-type 'flutter '("pubspec.yaml")
                                  :project-file "pubspec.yaml"
                                  :compile "flutter build"
                                  :test "flutter test"
                                  :run "flutter run"
                                  :test-suffix "_test")

(projectile-register-project-type 'python '("pyproject.toml")
                                  :project-file "pyproject.toml"
                                  :compile "uv sync"
                                  :test "uv run pytest"
                                  :run "uv run python main.py"
                                  :test-suffix "_test")

(setq projectile-create-missing-test-files t)

(provide 'projectile)
;;; projectile.el ends here
