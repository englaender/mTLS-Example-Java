# mTLS Example Java

This project contains a Server and a Client, which communicate via REST and encrypt their communication using mTLS.
Also a little **disclaimer** : take everything written here with a grain of salt. I'm neither an expert on mTLS nor on Java.

## mTLS excurse

As for the lingo : 
We have keypairs which consist of a public and a private key. 
Furthermore there are certificates which are public keys, wrapped with some additional information on the background of
said key i.e. the owner, issuer, usage, metadata.

I suppose most people know what mTLS is before stumbling over this project but in case you don't :
mTLS stands for mutual TLS. 

In regular TLS the client verfies the servers identity. This works
by the server providing a certificate, which is signed/trusted by some certificate authority (from here on called CA).
Using the CA's certificate, the client can then verify the authenticity of the signed server certificate.
So in the end the chain of trust is : Client trusts CA, CA trusts server, therefore the client trusts the server.

In mTLS the server verifies the client aswell (with the same procedure). 
This would not make sense for something like an online shop because they want all people to be able to access their 
site but a company might have internals where they know only a few machines will ever have to/should be allowed, 
to access them.

We will not go into certificate creation/signing etc. here (there is a script in this project that will do that for you
but more on that later).

To summarize :
The server/client will need it's own certificate signed by the CA and the CA's certificate.

## public and private key management in java

Java as always makes things more complicated than they need to be :
Two additional concepts, key- and truststores, have to be introduced, so just bear with me.

Truststore : 
holds the certificates that we trust, so whenever we receive a signed certificate from some other actor,
we look in our truststore, to see if there is any certificate that can verify the one we just got (by completing the 
chain of trust).
The JVM has it's own truststore btw which is called cacerts but more on that later.

Keystore :
holds private keys, certificates etc. usually for encrypting on our side or proving our identity to other actors.

So in our mTLS example we will need a truststore and a keystore for each the client and the server.
The truststore will always contain the CA certificate and the keystore will contain the corresponding 
(whether it's client or server) signed certificate.

BUT from a technical perspective they are both the exact same thing. You can see that by how they are imported. Both would
be loaded into type keystore. But java introduces this semantic difference as soon as you start working with them in the
context of ssl. Sorry for this mediocre joke, the class is called SLLContext.

As for the files themselves : 
the default format was JKS but is now PKCS12. 
You don't really have to care right now, unless you plan using certificates, which you got somewhere else.
To work with these files obviously another tool is needed because openssl doesn't support Javas fancy ideas.
That's what keytool is for, which is included in each Java release.
Java can work with regular .pem files etc. but I expected to be too much of a hassle.

## Get Started

Now that you know what's going on (or before, if you want to see whether this code even works and I can't blame you tbh)
let's get started with how to use all this code and stuff.

### Using the script

First we need to create certificates and but them in the right places.
The script in `/certificates` shall take care of that for you (well, mostly).
An important thing to note is that as of now we utilize the JVM truststore cacerts to manage the CA certificate.
To remove it use 
```bash
keytool -delete -cacerts -alias ca
```

The script has to be run as admin though because cacerts is modified.
If you want to change passwords for the resulting files (which you should) do it there (under the STEP 2 section).
Also if you intend to run your applications anywhere but on localhost, you'll have to change the IP references
accordingly.
This can be done using `-SubAlts` which allows you to set the subject alternative names (dnames are CN=CA and CN=SERVER).
Use it like this :
```bash
./genKeystore.ps1 -SubAlts c=DNS:localhost,IP:127.0.0.1 # this is the default
```
If you want to change the other extensions, have a look at [this documentation](https://access.redhat.com/documentation/en-us/red_hat_certificate_system/9/html/administration_guide/standard_x.509_v3_certificate_extensions#doc-wrapper).

After running all files will be placed where they have to be (resources folder of client and server) unless you tampered 
with the project structure.

In case you're interested in the content of a keystore file you can inspect them with
```bash
keytool -list -keystore <name> # you can also use -cacerts to access the jvm truststore
```

### Running the actual Server/Client

The following commands need to be executed from either `/Client` or `/Server`
Now to build the jdk using maven (gradle is supported in theory but I haven't maintained it, so who knows) execute
```bash
mvn clean package
```

If you want to simply run those use
```bash
java -jar <path to jar>
```

The Dockerfile expects `/target/mtls-server-0.0.1.jar` (created by the `mvn clean package` command, mentioned earlier).
Furthermore the root certificate ca.pem should be in `/Server`, so it can be added to cacerts of the image.
After that you can build the docker image with
```bash
docker build -t mtls-server-spring
```

And deploy the server to kubernetes using the following command but first you'll have to adapt the IP for the service 
under spec.clusterIP. The IP of course has to lie within your clusters IP range.
```bash
kubectl create -f service_deployment.yaml
```