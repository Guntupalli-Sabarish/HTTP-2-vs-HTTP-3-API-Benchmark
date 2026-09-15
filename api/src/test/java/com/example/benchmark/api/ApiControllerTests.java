package com.example.benchmark.api;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class ApiControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void healthReturnsStableJsonResponse() throws Exception {
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void productsDefaultsToTwentyDeterministicItems() throws Exception {
        mockMvc.perform(get("/api/products"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(20)))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].sku").value("SKU-00001"))
                .andExpect(jsonPath("$[0].name").value("Benchmark Product 0001"))
                .andExpect(jsonPath("$[0].category").value("books"))
                .andExpect(jsonPath("$[0].price").value(10.36));
    }

    @Test
    void productsReturnsOneThousandItems() throws Exception {
        mockMvc.perform(get("/api/products").param("limit", "1000"))
                .andExpect(status().isOk())
                .andExpect(contentTypeJson())
                .andExpect(jsonPath("$", hasSize(1000)))
                .andExpect(jsonPath("$[999].id").value(1000))
                .andExpect(jsonPath("$[999].sku").value("SKU-01000"));
    }

    @Test
    void productsRejectsLimitBelowOne() throws Exception {
        mockMvc.perform(get("/api/products").param("limit", "0"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void productsRejectsLimitAboveMaximum() throws Exception {
        mockMvc.perform(get("/api/products").param("limit", "1001"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void productsRejectsNonNumericLimit() throws Exception {
        mockMvc.perform(get("/api/products").param("limit", "many"))
                .andExpect(status().isBadRequest());
    }

    private static org.springframework.test.web.servlet.ResultMatcher contentTypeJson() {
        return org.springframework.test.web.servlet.result.MockMvcResultMatchers
                .content()
                .contentTypeCompatibleWith(MediaType.APPLICATION_JSON);
    }
}

