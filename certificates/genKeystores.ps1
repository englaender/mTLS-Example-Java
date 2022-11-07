# results in three PKCS12 keystores :
# client_keystore.pkcs12           : client key and signed cert and CA public cert (as a chain)
# server_keystore.pkcs12           : server key and signed cert and CA public cert (as a chain)
# truststore.pkcs12 (not used atm) : CA public cert
# Note:
# - script has to be run as admin because of keytool -cacerts -delete command
# - if you fill prompts to fast keytool might fail because it sucks and i.e. server.pkcs12 may still be accessed

$DEST_PATH="./build"
if (Test-Path -LiteralPath $DEST_PATH) {
    Remove-Item -LiteralPath $DEST_PATH -Recurse
}
mkdir $DEST_PATH

# create CA with a key and self signed cert
$CA_KEY_PASS="changeit"
$CA_STOREPASS="changeit"
keytool -genkeypair -keystore $DEST_PATH/ca.pkcs12 -alias ca -keypass $CA_KEY_PASS -storepass $CA_STOREPASS -keyalg RSA -keysize 2048 -dname CN=CA -deststoretype pkcs12 -ext KeyUsage=digitalSignature,keyCertSign -ext BasicConstraints=ca:true,PathLen:3

# create Server and Client key pairs aswell
$SERVER_KEY_PASS="changeit"
$SERVER_STOREPASS="changeit"
keytool -genkeypair -keystore $DEST_PATH/server.pkcs12 -alias server -keypass $SERVER_KEY_PASS -storepass $SERVER_STOREPASS -keyalg RSA -keysize 2048 -dname CN=SERVER -deststoretype pkcs12 -ext KeyUsage=digitalSignature,dataEncipherment,keyEncipherment,keyAgreement -ext ExtendedKeyUsage=serverAuth,clientAuth -ext SubjectAlternativeName:c=DNS:localhost,IP:127.0.0.1

# create Server and Client CSRs
keytool -certreq -keystore $DEST_PATH/server.pkcs12 -alias server -storepass $SERVER_STOREPASS -file $DEST_PATH/server.csr

# process CSRs by signing with CA keystore
keytool -gencert -keystore $DEST_PATH/ca.pkcs12 -alias ca -infile $DEST_PATH/server.csr -storepass $CA_STOREPASS -rfc -outfile $DEST_PATH/server.pem -ext KeyUsage=digitalSignature,dataEncipherment,keyEncipherment,keyAgreement -ext ExtendedKeyUsage=serverAuth,clientAuth -ext SubjectAlternativeName:c=DNS:localhost,IP:127.0.0.1

# export CA cert
keytool -exportcert -keystore $DEST_PATH/ca.pkcs12 -alias ca -file $DEST_PATH/ca.pem -storepass $CA_STOREPASS -rfc

# import CA cert and signed cert into Server and Client keystores
# CA cert is for the keystore to build the chain, but could be removed after
keytool -import -keystore $DEST_PATH/server.pkcs12 -storepass $SERVER_STOREPASS -file $DEST_PATH/ca.pem -alias ca -trustcacerts
keytool -import -keystore $DEST_PATH/server.pkcs12 -storepass $SERVER_STOREPASS -file $DEST_PATH/server.pem -alias server -trustcacerts

# create the truststore with one certificate, that is the CA cert
keytool -importcert -keystore $DEST_PATH/truststore.pkcs12 -file $DEST_PATH/ca.pem -storepass changeit -deststoretype pkcs12 -trustcacerts

# import ca cert to jvm truststore
keytool -delete -cacerts -alias ca
keytool -importcert -cacerts -trustcacerts -alias ca -file $DEST_PATH/ca.pem

# copy stores to required locations
cp $DEST_PATH/server.pkcs12 ../server_keystore.pkcs12
cp $DEST_PATH/truststore.pkcs12 ../truststore.pkcs12
cp $DEST_PATH/server.pkcs12 ../src/main/resources/server_keystore.pkcs12

Read-Host -Prompt "Press Enter to exit"