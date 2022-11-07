package com.example.restservice;

import org.apache.http.client.HttpClient;
import org.apache.http.conn.ssl.TrustSelfSignedStrategy;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.ssl.SSLContextBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import javax.net.ssl.SSLContext;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;

@SpringBootApplication
public class RestServiceApplication {

	@Value("${server.ssl.trust-store-pw}")
	private String trustStorePW;
	@Value("${server.ssl.key-store}")
	private String keyStorePath;
	@Value("${server.ssl.key-store-pw}")
	private String keyStorePW;
	@Value("${server.ssl.key-pw}")
	private String keyPW;
	@Value("${server.ssl.store-type}")
	private String storeType;

	public static void main(String[] args) {
		SpringApplication.run(RestServiceApplication.class, args);
	}

	@Bean
	@ConditionalOnProperty(
			value="server.use-mtls",
			havingValue = "true",
			matchIfMissing = false
	)
	public RestTemplate restTemplate() throws Exception {
		RestTemplate restTemplate = new RestTemplate(clientHttpRequestFactory());
		return restTemplate;
	}

	private ClientHttpRequestFactory clientHttpRequestFactory() throws Exception {
		return new HttpComponentsClientHttpRequestFactory(httpClient());
	}

	// prepares http client with ssl context, which contains the keystore configured in application.properties
	private HttpClient httpClient() throws Exception {
		// load stores from files
		KeyStore ks = keyStore(keyStorePath, keyStorePW.toCharArray());

		// create client with loaded stores (so the server can act as a client and verify the actual client)
		SSLContext sslContext = SSLContextBuilder
				.create()
				.loadKeyMaterial(ks, keyPW.toCharArray())
				.build();
		HttpClient client = HttpClients.custom().setSSLContext(sslContext).build();
		return client;
	}

	// helper to load keystore from given path
	private KeyStore keyStore(String file, char[] password)
			throws KeyStoreException, IOException, NoSuchAlgorithmException, CertificateException {
		KeyStore keyStore = KeyStore.getInstance(storeType);
		InputStream in = new FileInputStream(file);
		keyStore.load(in, password);
		return keyStore;
	}
}

