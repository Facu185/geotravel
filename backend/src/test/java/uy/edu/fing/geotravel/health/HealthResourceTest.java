package uy.edu.fing.geotravel.health;

import org.junit.Test;

import java.util.Map;

import static org.junit.Assert.assertEquals;

public class HealthResourceTest {

    @Test
    public void healthReturnsOkStatus() {
        HealthResource resource = new HealthResource();

        Map<String, Object> response = resource.health();

        assertEquals("ok", response.get("status"));
        assertEquals("geotravel-backend", response.get("service"));
    }
}
