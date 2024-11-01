after kubectl creation:

    kubectl apply -f postgres.yaml

Activate a port-forward to access Postgres:

    kubectl describe pod spi-dev-db-9746cb489-2srb9
    # kubectl port-forward pod/postgres-0 9999:5432
    kubectl port-forward pod/spi-dev-db-9746cb489-2srb9 9999:5432

you'll see:

    Forwarding from 127.0.0.1:9999 -> 5432
    Forwarding from [::1]:9999 -> 5432

Then, to access the db, you can use psql on the CLI:

    psql --host localhost --port 9999 --username postgres --dbname postgres
    psql -h localhost -p 9999 -U spi_dev -d spi_dev -c 'CREATE ROLE azure_pg_admin; CREATE ROLE azuresu;'
    pg_restore --no-owner -h localhost -p 9999 -U spi_dev -d spi_dev <  ~/src/SwiftPackageIndex-Server/spi_prod-2024-09-01.dump

to clean up:

    kubectl delete -f postgres.yaml

Kubectl Postgres CLI:

    kubectl run -i --tty --rm debug --image=postgres:16-alpine --restart=Never -- sh

showing environment variables injected:

`env`:
```
KUBERNETES_SERVICE_PORT=443
KUBERNETES_PORT=tcp://10.96.0.1:443
HOSTNAME=debug
SHLVL=1
DOCKER_PG_LLVM_DEPS=llvm15-dev 		clang15
HOME=/root
PG_VERSION=16.4
POSTGRES_SERVICE_PORT_POSTGRES_5432_TCP=5432
TERM=xterm
KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
POSTGRES_PORT_5432_TCP_ADDR=10.101.75.38
KUBERNETES_PORT_443_TCP_PORT=443
KUBERNETES_PORT_443_TCP_PROTO=tcp
POSTGRES_SERVICE_HOST=10.101.75.38
LANG=en_US.utf8
POSTGRES_PORT_5432_TCP_PORT=5432
POSTGRES_PORT_5432_TCP_PROTO=tcp
POSTGRES_PORT=tcp://10.101.75.38:5432
POSTGRES_SERVICE_PORT=5432
KUBERNETES_SERVICE_PORT_HTTPS=443
PG_SHA256=971766d645aa73e93b9ef4e3be44201b4f45b5477095b049125403f9f3386d6f
KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
PG_MAJOR=16
GOSU_VERSION=1.17
POSTGRES_PORT_5432_TCP=tcp://10.101.75.38:5432
PWD=/
KUBERNETES_SERVICE_HOST=10.96.0.1
PGDATA=/var/lib/postgresql/data
```

WebApp setup:

    kubectl create deployment webapp --image=registry.gitlab.com/finestructure/swiftpackageindex:2.112.1 --port=8080

`kubectl describe deployment webapp`:

```
Name:                   webapp
Namespace:              default
CreationTimestamp:      Fri, 01 Nov 2024 12:54:40 -0700
Labels:                 app=webapp
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=webapp
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=webapp
  Containers:
   swiftpackageindex:
    Image:         registry.gitlab.com/finestructure/swiftpackageindex:2.112.1
    Port:          8080/TCP
    Host Port:     0/TCP
    Environment:   <none>
    Mounts:        <none>
  Volumes:         <none>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   webapp-5b9fdd97b9 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  69s   deployment-controller  Scaled up replica set webapp-5b9fdd97b9 to 1
```


kubectl apply -f webapp-deployment.yaml
kubectl get -f webapp-deployment.yaml
kubectl describe -f webapp-deployment.yaml

kubectl logs pod/webapp-677d9d79df-nzrfb -c init-wait-postgres # Inspect the first init container
kubectl logs pod/webapp-677d9d79df-nzrfb -c init-migrate-schema   # Inspect the second init container

