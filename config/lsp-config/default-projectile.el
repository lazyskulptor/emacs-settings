(use-package projectile
  :ensure t
  :init
  (projectile-mode +1)
  :bind (:map projectile-mode-map
              ("s-p" . projectile-command-map)
              ("C-c p" . projectile-command-map)))

(projectile-register-project-type 'maven '("pom.xml")
                                  :project-file "pom.xml"
				  :compile "./mvnw -B clean install"
				  :test "./mvnw -B test"
				  :run "./mvnw spring-boot:run"
                                  :test-suffix "Tests")

(provide 'default-projectile)
