(setq sql-connection-alist
   '(("sq-dev"
      (sql-product 'mysql)
      (sql-user "sctestuser")
      (sql-password "sctestpassword")
      (sql-server "sc-dev.cluster-cbdq90ulypkj.ap-northeast-2.rds.amazonaws.com")
      (sql-database "sc_test_db")
      (sql-port 3307))
     ("local-h2"
      (sql-product 'h2)
      (sql-user "sctestuser")
      (sql-password "sctestpassword")
      (sql-server "sc-dev.cluster-cbdq90ulypkj.ap-northeast-2.rds.amazonaws.com")
      (sql-database "sc_test_db")
      (sql-port 3307))
     ))

;;  end of file
(provide 'sql-connection)
