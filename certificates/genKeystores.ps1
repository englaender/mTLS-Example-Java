# results in three PKCS12 keystores (and files from intermediate steps):
# client_keystore.pkcs12           : client key and signed cert and CA public cert (as a chain)
# server_keystore.pkcs12           : server key and signed cert and CA public cert (as a chain)
# truststore.pkcs12 (not used atm) : CA public cert
# Note:
# - script has to be run as admin because of keytool -cacerts -delete command
# - if you fill prompts to fast keytool might fail because it sucks and i.e. server.pkcs12 may still be accessed

# for more documentation on program params see README.md
param(
    [string]$SubAlts="c=DNS:localhost,IP:127.0.0.1" # subject alternative names extension for server certificate
)

# clear destination for all intermediate files
$DEST_PATH="./build"
if (Test-Path -LiteralPath $DEST_PATH) {
    Remove-Item -LiteralPath $DEST_PATH -Recurse
}
mkdir $DEST_PATH

# Creates a new keystore named $StoreName.pkcs12, with a keypair identified by alias $StoreName, where the key is
# protected with $KeyPass and the store with $Storepass. The certificate will be eligebile for dname $StoreName and
# $SubAlts (see README.md). The public part is then signed by $CAStore.pkcs12 (where the alias is $CAStore aswell
# and protected by  $CAStorePass). $CAStore.pkcs12 is expected to be under $DEST_PATH along with $CAStore.pem,
# which is imported into $StoreName.pkcs12, followedd by the signed certificate.
# keys are RSA 2048 encrypted, and eligible for :
#  digitalSignature,dataEncipherment,keyEncipherment,keyAgreement,serverAuth and clientAuth
function Get-SignedCert {
    Param (
        [string]$StoreName="example",   # name for the new keystore and it's elements
        [string]$KeyPass="changeit",    # password for the new key
        [string]$StorePass="changeit",  # password for the new keystore
        [string]$SubAlts=$null,         # content for the subject alternative names extension
        [string]$CAStore="ca",          # path to the store that represents the CA
        [string]$CAStorePass="changeit" # password for the store that represents the CA
    )

    # create new store as keypair
    keytool -genkeypair `
        -keystore $DEST_PATH/$StoreName.pkcs12 `
        -alias $StoreName `
        -keypass $KeyPass `
        -storepass $StorePass `
        -keyalg RSA `
        -keysize 2048 `
        -dname CN=$StoreName `
        -deststoretype pkcs12 `
        -ext KeyUsage=digitalSignature,dataEncipherment,keyEncipherment,keyAgreement `
        -ext ExtendedKeyUsage=serverAuth,clientAuth `
        -ext SubjectAlternativeName:$SubAlts

    # create CSR from new store
    keytool -certreq `
        -keystore $DEST_PATH/$StoreName.pkcs12 `
        -alias $StoreName `
        -storepass $StorePass `
        -file $DEST_PATH/$StoreName.csr

    # process CSRs by signing with CA keystore
    keytool -gencert `
        -keystore $DEST_PATH/$CAStore.pkcs12 `
        -alias $CAStore `
        -infile $DEST_PATH/$StoreName.csr `
        -storepass $CAStorePass `
        -rfc `
        -outfile $DEST_PATH/$StoreName.pem `
        -ext KeyUsage=digitalSignature,dataEncipherment,keyEncipherment,keyAgreement `
        -ext ExtendedKeyUsage=serverAuth,clientAuth `
        -ext SubjectAlternativeName:$SubAlts

    # import CA cert and signed cert into Server and Client keystores
    # CA cert is for the keystore to build the chain, but could be removed after
    keytool -import `
        -keystore $DEST_PATH/$StoreName.pkcs12 `
        -storepass $StorePass `
        -file $DEST_PATH/$CAStore.pem `
        -alias $CAStore `
        -trustcacerts
    keytool -import `
        -keystore $DEST_PATH/$StoreName.pkcs12 `
        -storepass $StorePass `
        -file $DEST_PATH/$StoreName.pem `
        -alias $StoreName `
        -trustcacerts
}

#######################################
# STEP 1 : CREATE KEYSTORE TO MIMIC CA
#######################################

# create CA with a key and self signed cert
$CA_KEY_PASS="changeit"
$CA_STORE_PASS="changeit"
keytool -genkeypair `
    -keystore $DEST_PATH/ca.pkcs12 `
    -alias ca `
    -keypass $CA_KEY_PASS `
    -storepass $CA_STORE_PASS `
    -keyalg RSA `
    -keysize 2048 `
    -dname CN=CA `
    -deststoretype pkcs12 `
    -ext KeyUsage=digitalSignature,keyCertSign `
    -ext BasicConstraints=ca:true,PathLen:3

# export CA cert
keytool -exportcert `
    -keystore $DEST_PATH/ca.pkcs12 `
    -alias ca `
    -file $DEST_PATH/ca.pem `
    -storepass $CA_STORE_PASS `
    -rfc

#######################################
# STEP 2 : CREATE SERVER AND CLIENT KS
#######################################

$SERVER_STORE_PASS="changeit"
$SERVER_KEY_PASS="changeit"
Get-SignedCert -StoreName server `
    -KeyPass $SERVER_KEY_PASS `
    -StorePass $SERVER_STORE_PASS `
    -CAStore ca `
    -CAStorePass $CA_STORE_PASS `
    -SubAlts $SubAlts

$CLIENT_STORE_PASS="changeit"
$CLIENT_KEY_PASS="changeit"
Get-SignedCert -StoreName client `
    -KeyPass $CLIENT_KEY_PASS `
    -StorePass $CLIENT_STORE_PASS `
    -CAStore ca `
    -CAStorePass $CA_STORE_PASS `
    -SubAlts $SubAlts               # TODO : client doesn't need them, but splatting didn't work

#######################################
# STEP 3 : PREPARE TRUSTSTORES
#######################################

# create the truststore with one certificate, that is the CA cert
keytool -importcert `
    -keystore $DEST_PATH/truststore.pkcs12 `
    -file $DEST_PATH/ca.pem `
    -storepass changeit `
    -deststoretype pkcs12 `
    -trustcacerts

# import ca cert to jvm truststore
keytool -delete -cacerts -alias ca
keytool -importcert `
    -cacerts `
    -trustcacerts `
    -alias ca `
    -file $DEST_PATH/ca.pem

#######################################
# STEP 4 : PUT KS IN CORRECT PLACES
#######################################

# copy stores to required locations (resources)
cp $DEST_PATH/server.pkcs12 ../Server/src/main/resources/server_keystore.pkcs12
cp $DEST_PATH/client.pkcs12 ../Client/src/main/resources/client_keystore.pkcs12

Read-Host -Prompt "Press Enter to exit"