(setq sql-connection-alist
'((local-pg
(sql-product 'postgres)
(sql-server "127.0.0.1")
(sql-user "postgres")
(sql-password "mysecretpassword")
(sql-database "postgres")
(sql-port 5432))))

(provide 'sql-connections)
