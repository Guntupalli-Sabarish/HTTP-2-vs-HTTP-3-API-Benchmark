# API contract

The benchmark API is intentionally database-free. Every successful response is generated deterministically from the request parameters, so HTTP/2 and HTTP/3 tests exercise identical application logic and payloads.

The Spring Boot application listens on `http://localhost:8080` during local development. HTTPS and protocol negotiation will be added at later checkpoints by Caddy.

## `GET /api/health`

Returns a small, fixed JSON response.

```json
{"status":"UP"}
```

## `GET /api/products`

Returns a JSON array of deterministic products in ascending `id` order.

| Query parameter | Default | Allowed range | Description |
| --- | --- | --- | --- |
| `limit` | `20` | Integer from `1` through `1000` | Number of products returned. |

Examples:

```text
GET /api/products
GET /api/products?limit=20
GET /api/products?limit=1000
```

The first product is always:

```json
{
  "id": 1,
  "sku": "SKU-00001",
  "name": "Benchmark Product 0001",
  "category": "books",
  "price": 10.36
}
```

Invalid, non-numeric, zero, negative, or greater-than-`1000` `limit` values return HTTP `400 Bad Request`.

## Determinism guarantee

For the same endpoint and `limit` value, the API returns products with the same field names, values, ordering, and JSON array order. The API does not inspect the inbound protocol, TLS, headers, client identity, or network condition when generating a response.
