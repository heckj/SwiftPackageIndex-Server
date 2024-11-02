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

fiddling/debugging:

    kubectl apply -f webapp-deployment.yaml
    kubectl get -f webapp-deployment.yaml
    kubectl describe -f webapp-deployment.yaml

    kubectl logs pod/webapp-677d9d79df-nzrfb -c init-wait-postgres # Inspect the first init container
    kubectl logs pod/webapp-677d9d79df-nzrfb -c init-migrate-schema   # Inspect the second init container

Kustomize:

    kubectl apply -k k8s/dev
    kubectl logs pod/webapp-bf4b45945-w9c6m -c init-migrate-schema -n dev   
    kubectl delete -k k8s/dev

### Quirks and workarounds spotted so far:

- No “depends_on” for containers running in Kubernetes, like we’re currently leveraging for
update rollouts in Docker swarm
 - Kubernetes setup takes the stance that app instances should be “decoupled” and “wait and retry”
 (or crash and retry) rather than setting up explicit dependencies. That said, they have a bit of
 some mechanism in place with the idea of “Init Containers” - which are run and completed _before_
 the main container is run, which can be used as a sort of dependency mechanism (common example is
 “wait on db”)
 - What happens if the migrations _aren’t_ up to date? Do apps fail and crash? Something else?

- Local-dev with Kubernetes: bootstrapping and restoring a snapshot DB to an instance *in* Kubernetes
is sorta awkward. Have at least one direct path with a `kubectl port-forward` command that can access
a local Postgres instance, but it may make a LOT more sense to keep with just a docker instance and
“compose” for local development.
 - Pretty sure there’s a path to locally port-forwarding 5432 to a local DB instance, working on that
 - Have a “stateful set” creation enabled for Postgres DB with local DB files stored on disk for
 dev purposes / as a trial

- There are multiple ways to run “Kubernetes” locally. One is Docker Desktop, which comes with a Kubernetes mode
enabled “out of the box”. Another common one is “Minikube” - which is hopelessly configurable, so it was
be awkward to align between developers, but allows for a lot of different options, including a default
of using Docker Desktop locally (different from Docker’s k8s, but still using it) if it’s installed.
Alternatively, there’s a QEMU driver, and a few other interesting variants. And it’s apparently got a
macOS app for helping to control it
(Minikube GUI: https://minikube.sigs.k8s.io/docs/tutorials/setup_minikube_gui/) which is a little Qt
app (note: it’s unsigned, so you need to manually unquarantine it to enable it to run)
