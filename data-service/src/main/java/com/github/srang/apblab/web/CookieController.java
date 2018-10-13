package com.github.srang.apblab.web

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/cookies")
public class CookieController {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public String listInventory() {
        return "{ \"msg\": \"no users currently configured\" }"
    }
}