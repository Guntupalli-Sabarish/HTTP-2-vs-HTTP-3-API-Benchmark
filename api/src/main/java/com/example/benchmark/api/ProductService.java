package com.example.benchmark.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.IntStream;

import org.springframework.stereotype.Service;

@Service
public class ProductService {

    public static final int MAX_LIMIT = 1_000;
    private static final List<String> CATEGORIES = List.of("books", "electronics", "home", "sports", "toys");

    public List<Product> findProducts(int limit) {
        return IntStream.rangeClosed(1, limit)
                .mapToObj(this::productFor)
                .toList();
    }

    private Product productFor(int id) {
        return new Product(
                id,
                "SKU-%05d".formatted(id),
                "Benchmark Product %04d".formatted(id),
                CATEGORIES.get((id - 1) % CATEGORIES.size()),
                BigDecimal.valueOf(999 + (id * 37L), 2)
        );
    }
}

