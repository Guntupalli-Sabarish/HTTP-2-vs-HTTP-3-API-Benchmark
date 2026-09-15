package com.example.benchmark.api;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
@Validated
public class ApiController {

    private final ProductService productService;

    public ApiController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping("/health")
    public HealthResponse health() {
        return new HealthResponse("UP");
    }

    @GetMapping("/products")
    public List<Product> products(
            @RequestParam(defaultValue = "20")
            @Min(value = 1, message = "limit must be at least 1")
            @Max(value = ProductService.MAX_LIMIT, message = "limit must be at most 1000")
            int limit
    ) {
        return productService.findProducts(limit);
    }
}

