# BitVelocity Monorepo

Source code : [https://github.com/nitinkc/BitVelocity](https://github.com/nitinkc/BitVelocity)

Site: [https://nitinkc.github.io/BitVelocity-Docs/](https://nitinkc.github.io/BitVelocity-Docs/)

Project URL : [https://github.com/users/nitinkc/projects/8](https://github.com/users/nitinkc/projects/8)


## Build All Modules

```
cd bv-core-parent
mvn clean install
```

bv-core-platform-bom (controls all versions) -> bv-core-parent (controls plugins etc.) -> bv-core-parent (this goes into every domain)


## Start Infrastructure (Local)

```
cd scripts/dev
# On Windows:
docker-compose -f docker-compose.infra.yml up -d
```

## Run Authentication Service (Local)

```
cd auth-service
mvn spring-boot:run
```

## Kubernetes (Kind/Minikube)

```
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/auth-service.yaml
```

## Documentation
- Architecture: `BitVelocity-Docs/docs/00-OVERVIEW/README.md`
- Security: `BitVelocity-Docs/adr/ADR-005-security-layering.md`

---

For more details, see `QUICK-START.md`.

