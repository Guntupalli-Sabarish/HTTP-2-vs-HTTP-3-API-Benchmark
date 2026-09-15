package com.example.benchmark.api;

import java.math.BigDecimal;

public record Product(
        int id,
        String sku,
        String name,
        String category,
        BigDecimal price
) {
}

