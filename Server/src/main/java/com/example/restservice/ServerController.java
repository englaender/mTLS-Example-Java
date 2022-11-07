package com.example.restservice;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ServerController {

    @GetMapping(value = "/pong")
    public String getMessage() {
        System.out.println("Request received for /pong, responding with 'pong'");
        return "pong";
    }
}