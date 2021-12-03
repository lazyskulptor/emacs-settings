(projectile-register-project-type 'maven '("pom.xml")
                                  :project-file "pom.xml"
				  :compile "./mvnw -B clean install"
				  :test "./mvnw -B test"
				  :run "./mvnw spring-boot:run"
                                  :test-suffix "Tests")

(provide 'default-projectile)
