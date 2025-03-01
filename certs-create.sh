#!/bin/bash

#set -o nounset \
#    -o errexit \
#    -o verbose \
#    -o xtrace

# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12 extfile

TAG=7.0.2

# Generate CA key
docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} openssl req -new -x509 -keyout /tmp/snakeoil-ca-1.key -out /tmp/snakeoil-ca-1.crt -days 9999 -subj '/CN=ca1.test.confluent.io/OU=TEST/O=CONFLUENT/L=PaloAlto/ST=Ca/C=US' -passin pass:confluent -passout pass:confluent

for i in http-service-mtls-auth http-service-ssl-basic-auth
do
    echo "------------------------------- $i -------------------------------"

    # Create host keystore
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} keytool -genkey -noprompt \
                 -alias $i \
                 -dname "CN=$i,OU=TEST,O=CONFLUENT,L=PaloAlto,S=Ca,C=US" \
                                 -ext "SAN=dns:$i,dns:localhost" \
                 -keystore /tmp/keystore.$i.jks \
                 -keyalg RSA \
                 -storepass confluent \
                 -keypass confluent \
                 -storetype pkcs12

    # Create the certificate signing request (CSR)
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} keytool -keystore /tmp/keystore.$i.jks -alias $i -certreq -file /tmp/$i.csr -storepass confluent -keypass confluent -ext "SAN=dns:$i,dns:localhost"
        #openssl req -in $i.csr -text -noout

cat << EOF > extfile
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = $i
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $i
DNS.2 = localhost
EOF
        # Sign the host certificate with the certificate authority (CA)
        docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} openssl x509 -req -CA /tmp/snakeoil-ca-1.crt -CAkey /tmp/snakeoil-ca-1.key -in /tmp/$i.csr -out /tmp/$i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:confluent -extensions v3_req -extfile /tmp/extfile

        #openssl x509 -noout -text -in $i-ca1-signed.crt

        # Sign and import the CA cert into the keystore
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} keytool -noprompt -keystore /tmp/keystore.$i.jks -alias CARoot -import -file /tmp/snakeoil-ca-1.crt -storepass confluent -keypass confluent
        #keytool -list -v -keystore kafka.$i.keystore.jks -storepass confluent

        # Sign and import the host certificate into the keystore
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG}  keytool -noprompt -keystore /tmp/keystore.$i.jks -alias $i -import -file /tmp/$i-ca1-signed.crt -storepass confluent -keypass confluent -ext "SAN=dns:$i,dns:localhost"
        #keytool -list -v -keystore kafka.$i.keystore.jks -storepass confluent

    # Create truststore and import the CA cert
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG}  keytool -noprompt -keystore /tmp/truststore.$i.jks -alias CARoot -import -file /tmp/snakeoil-ca-1.crt -storepass confluent -keypass confluent

    # Save creds
      echo  "confluent" > ${i}_sslkey_creds
      echo  "confluent" > ${i}_keystore_creds
      echo  "confluent" > ${i}_truststore_creds

    # Create pem files and keys used for Schema Registry HTTPS testing
    #   openssl x509 -noout -modulus -in client.certificate.pem | openssl md5
    #   openssl rsa -noout -modulus -in client.key | openssl md5
    #   log "GET /" | openssl s_client -connect localhost:8085/subjects -cert client.certificate.pem -key client.key -tls1
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} keytool -export -alias $i -file /tmp/$i.der -keystore /tmp/keystore.$i.jks -storepass confluent
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} openssl x509 -inform der -in /tmp/$i.der -out /tmp/$i.certificate.pem
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} keytool -importkeystore -srckeystore /tmp/keystore.$i.jks -destkeystore /tmp/$i.keystore.p12 -deststoretype PKCS12 -deststorepass confluent -srcstorepass confluent -noprompt
    docker run -v $PWD:/tmp vdesabou/kafka-docker-playground-connect:${TAG} openssl pkcs12 -in /tmp/$i.keystore.p12 -nodes -nocerts -out /tmp/$i.key -passin pass:confluent

    cp keystore.$i.jks src/main/resources/keystore.$i.jks
    cp truststore.$i.jks src/main/resources/truststore.$i.jks
done