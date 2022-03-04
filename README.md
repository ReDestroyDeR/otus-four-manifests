# Otus API Gateway Homework
In this homework I have implemented two key services:
* Authentication Service
* CRUD Service (aka. Business Service)

In my implementation services are highly coupled and Authentication Service
knows a lot about API of the other

Transport protocol: HTTP

Database Access protocol: R2DBC (CRUD) and JDBC (Auth)

Service mesh: Istio


### Installation
1. Install istiod 
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
kubectl create namespace istio-system
helm install istio-base istio/base -n istio-system
helm install istiod istio/istiod -n istio-system --wait
```
2. Install istio-ingress
```bash
kubectl create namespace istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled
helm install istio-ingress istio/gateway -n istio-ingress --wait
```
3. Install contents of this folder by running `bootstrap.sh`
4. Check out the API by importing Postman Collection!

**!!!** *EnvoyFilter may not be working due to long startup time of Authentication Service, so feel free to 
`kubectl rollout restart -n istio-system dep/istiod`*

## Sequence Diagrams describing Flow

### Registration

```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Authentication Service
    participant Business Service
    participant PostgreSQL

    User->>+Gateway: Register New User
    Gateway->>+Authentication Service: POST /register
    activate Authentication Service
    alt Username Validation
    Authentication Service->>PostgreSQL: [AUTH DB] Persist User Credentials
    else Bad username
    Authentication Service->>-Gateway: 402 Bad Request
    Gateway->>User: 402 Bad Request
    end

    alt User creation propagation
    Authentication Service->>+Business Service: POST /create-user
    Business Service->>PostgreSQL: [BUSINESS DB] Persist User
    Business Service->>Authentication Service: OK 200
    else Internal Exception
    Business Service->>-Authentication Service: Error
    Authentication Service->>Gateway: Error
    Gateway->>User: Error
    end

    Authentication Service->>-Gateway: OK 200
    Gateway->>-User: OK 200
```

### Login

```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Authentication Service
    participant PostgreSQL

    User->>+Gateway: POST /login
    Gateway->>+Authentication Service: POST /login
    Authentication Service->>+PostgreSQL: [AUTH DB] Fetch Password for Username
    alt User Exists
    PostgreSQL->>Authentication Service: Password
       else User doesn't exist
    PostgreSQL->>-Authentication Service: 0
    Authentication Service->>Gateway: 404 Not Found
    Gateway->>User: 404 Not Found
    end
    alt Password is correct
    Authentication Service->>Gateway: JWT
    Gateway->>User: JWT
    else Incorrect password
    Authentication Service->>-Gateway: 403 Bad Password
    Gateway->>-User: 403 Bad Password
    end
```

### Business Service Interactions

```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Envoy Filter
    participant Business Service
    participant Authentication Service
    
    loop istiod JWKs update
    Envoy Filter->>+Authentication Service: GET /.well-known/jwks.json
    Authentication Service->>-Envoy Filter: JWKs
    end
    
    User->>+Gateway: PATCH /update
    User->>Gateway: GET /?username={id}
    Note over User, Gateway: Authorization: Bearer
    Gateway->>+Envoy Filter: Request
    alt Not Valid JWT
    Envoy Filter->>Gateway: 403 Bad JWT
    Gateway->>User: 403 Bad JWT
    else Body or Query username matches JWT Subject
    Envoy Filter->>+Business Service: Request
    Business Service->>-Gateway: Response
    Gateway->>User: Response 
    else Body or Query username doesn't match
    Envoy Filter->>-Gateway: 403 No access to target resource
    Gateway->>-User: 403 No access to target resource
    end
```

## Change username
```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Authentication Service
    participant Business Service
    participant PostgreSQL
    
    User->>+Gateway: POST /change-username?username={new-username}
    Gateway->>+Authentication Service: POST /change-username?username={new-username}
    alt Bad credentials
    Authentication Service->>Gateway: 403 Forbidden
    Gateway->>User: 402 Forbidden
    else Valid credentials
    alt New username is not occupied
    Authentication Service->>+PostgreSQL: [AUTH DB] Update username
    PostgreSQL->>Authentication Service: 1
    else New username is occupied
    PostgreSQL->>-Authentication Service: 0
    Authentication Service->>Gateway: 402 Bad Request
    Gateway->>User: 402 Bad Request
    end
    alt Username is not occupied in business database
    Authentication Service->>+Business Service: PATCH /change-username?username={new-username}
    Business Service->>+PostgreSQL: [BUSIENSS DB] Update username
    PostgreSQL->>Business Service: 1
    Business Service->>Authentication Service: 200 OK
    Authentication Service->>Gateway: 200 OK
    Gateway->>User: 200 OK
    else Username is already occupied in business database
    PostgreSQL->>-Business Service: 0
    Business Service->>-Authentication Service: 402 Bad Request
    Authentication Service->>-Gateway: 402 Bad Request
    Gateway->>-User: 402 Bad Request
    end
    end
```

## Change password
```mermaid
sequenceDiagram
    actor User
    participant Gateway
    participant Authentication Service
    participant PostgreSQL
    
    User->>+Gateway: POST /change-password?password={new-password}
    Gateway->>+Authentication Service: POST /change-password?password={new-password}
    alt Bad credentials
    Authentication Service->>Gateway: 403 Forbidden
    Gateway->>User: 402 Forbidden
    else Valid credentials
    Authentication Service->>+PostgreSQL: [AUTH DB] Update password
    PostgreSQL->>-Authentication Service: 1
    Authentication Service->>-Gateway: 200 OK
    Gateway->>-User: 200 OK
    end
```