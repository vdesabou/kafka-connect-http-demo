# Kafka Connect HTTP Sink Demo App

*NOTICE: This app is for demo purposes only and is not suitable for production use.*

A Spring Boot app that can run with various types of auth configured by setting the appropriate Spring Profile.

This app is useful in testing the HTTP Sink Connector.

## Supported Security Types

- Simple Auth (No Authentication) (Profile: `simple-auth`)
- Basic Auth (Profile: `basic-auth`)
- OAuth2 (Profile: `oauth2`)
- SSL with Basic Auth (Profile: `ssl-basic-auth`)
- SSL with Mutual TLS Auth (Profile: `ssl-auth`)

## Simple (No) Auth

1. Set profile
    ```
    SPRING_PROFILES_ACTIVE=simple-auth
    ```

2. Run the app
3. Call any endpoint

    ```bash
    # create a message
    curl -X POST \
      http://localhost:8080/api/messages \
      -d message-goes-here

    # get all messages
    curl -X POST http://localhost:8080/api/messages
    ```

## Basic Auth

1. Set profile
    ```
    SPRING_PROFILES_ACTIVE=basic-auth
    ```

2. Run the app
3. Call endpoints with Basic Auth Header
    ```bash
    # create a message
    curl -X POST \
      http://localhost:8080/api/messages \
      -H 'Authorization: Basic YWRtaW46cGFzc3dvcmQ='
      -d message-goes-here

    # get all messages
    curl -X POST \
      http://localhost:8080/api/messages \
      -H 'Authorization: Basic YWRtaW46cGFzc3dvcmQ='
    ```

## OAuth2

1. Set profile
    ```
    SPRING_PROFILES_ACTIVE=oauth2
    ```

2. Run the app
3. Create Token
    ```bash
    curl -X POST \
      http://localhost:8080/oauth/token \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      -H 'Authorization: Basic a2MtY2xpZW50OmtjLXNlY3JldA==' \
      -d 'grant_type=client_credentials&scope=any'
    ```
4. Use Token (substitute `{token}` with value from previous step)
    ```
    # create a message
    curl -X POST \
      http://localhost:8080/api/messages \
      -H 'Authorization: Bearer {token}'
      -d message-goes-here

    curl -X GET \
        http://localhost:8080/api/messages \
        -H 'Authorization: Bearer {token}'
    ```

## SSL with Basic auth

1. Set profile
    ```
    SPRING_PROFILES_ACTIVE=ssl-basic-auth
    ```
2. Use certs with `http-service-ssl-basic-auth` names in root of project to call endpoints

Notes:
* _port `8443` is used instead of `8080`_
* _keystore.http-service-ssl-basic-auth.jks and _truststore.http-service-ssl-basic-auth.jks were generated with this command:_
    ```bash
     ./certs-create.sh
    ```

## SSL with mutual TLS auth

1. Set profile
    ```
    SPRING_PROFILES_ACTIVE=ssl-auth
    ```
2. Use certs with `http-service-mtls-auth` names in root of project to call endpoints

Notes:
* _port `8443` is used instead of `8080`_
* _keystore.http-service-mtls-auth.jks and _truststore.http-service-mtls-auth.jks were generated with this command:_
    ```bash
     ./certs-create.sh
    ```

docker buildx build --push --tag vdesabou/nginx_proxy:latest -o type=image --platform=linux/arm64,linux/amd64 .