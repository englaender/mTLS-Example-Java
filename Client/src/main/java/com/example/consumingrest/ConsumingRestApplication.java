package com.example.consumingrest;


import org.apache.http.client.HttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.ssl.SSLContextBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
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
public class ConsumingRestApplication {

	@Value("${client.ssl.trust-store-pw}")
	private String trustStorePW;
	@Value("${client.ssl.key-store}")
	private String keyStorePath;
	@Value("${client.ssl.key-store-pw}")
	private String keyStorePW;
	@Value("${client.ssl.key-pw}")
	private String keyPW;
	@Value("${client.ssl.store-type}")
	private String storeType;
	@Value("${client.connect.base-url}")
	private String baseURL;

	public static void main(String[] args) {
		SpringApplication.run(ConsumingRestApplication.class, args);
	}

	@Bean
	public RestTemplate restTemplate() throws Exception {
		RestTemplate restTemplate = new RestTemplate(clientHttpRequestFactory());
		return restTemplate;
	}

	// example request to the server
	@Bean
	public CommandLineRunner run(RestTemplate restTemplate) throws Exception {
		return args -> {
			String pong = restTemplate.getForObject(
					baseURL + "/pong", String.class);
			System.out.println(pong);
		};
	}

	private ClientHttpRequestFactory clientHttpRequestFactory() throws Exception {
		return new HttpComponentsClientHttpRequestFactory(httpClient());
	}


	// prepares http client with ssl context, which contains the keystore configured in application.properties
	private HttpClient httpClient() throws Exception {
		// load stores from files
		KeyStore ks = keyStore(keyStorePath, keyStorePW.toCharArray());

		// create client with loaded stores
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
