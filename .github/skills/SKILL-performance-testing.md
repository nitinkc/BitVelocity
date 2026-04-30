# Skill: Performance Testing & Benchmarking

## Purpose
Design, implement, and execute performance tests using Gatling and k6 to validate latency, throughput, and reliability targets.

## When to Use This Skill
- Creating load tests for a new service or endpoint
- Establishing performance baselines
- Validating performance optimization changes
- Testing resilience under load (circuit breakers, timeouts)
- Regression testing in CI/CD pipelines
- Capacity planning for production deployment

---

## Step 1: Define Performance Targets

### 1.1 SLI/SLO Definition

**File**: `bv-performance-testing/performance-baselines/sli-targets.yaml`

```yaml
# Service Level Indicators (SLI) and Objectives (SLO)

services:
  order-service:
    endpoints:
      POST /api/v1/orders:
        description: Create new order
        latency:
          p50: 50ms
          p95: 200ms
          p99: 500ms
        throughput: 100 req/sec
        error_rate: 0.1%
        availability_slo: 99.9%
      
      GET /api/v1/orders/{orderId}:
        description: Retrieve order details
        latency:
          p50: 20ms
          p95: 100ms
          p99: 250ms
        throughput: 500 req/sec
        error_rate: 0.05%
        availability_slo: 99.95%
    
    gRPC:
      ReserveStock:
        description: Synchronous inventory check
        latency:
          p50: 30ms
          p95: 100ms
          p99: 200ms
        throughput: 200 req/sec
        error_rate: 0.1%

  payment-service:
    endpoints:
      POST /api/v1/payments/authorize:
        latency:
          p50: 100ms
          p95: 300ms
          p99: 1000ms  # External payment gateway included
        throughput: 50 req/sec
        error_rate: 0.5%
        availability_slo: 99.5%

load_profile:
  peak_concurrent_users: 10000
  peak_throughput: 500 req/sec
  daily_peak_duration_hours: 2
  growth_rate_yoy: 1.5x
  database_size_estimate_gb: 50
```

### 1.2 Test Matrix

Define what scenarios to test:

```markdown
## Performance Test Strategy

### Baseline Test
- Concurrent users: 50
- Duration: 5 minutes
- Ramp-up: 1 min
- Hold: 4 min  
- Ramp-down: Linear
- Success criteria: p95 < 200ms, error rate < 0.1%

### Throughput/Soak Test
- Concurrent users: 100-500 (gradually increase)
- Duration: 1 hour
- Purpose: Identify memory leaks, connection pool exhaustion
- Success criteria: p95 < 200ms sustained, no errors

### Spike Test
- Baseline: 100 users
- Spike: 1000 users (5x increase) for 2 minutes
- Purpose: Test circuit breaker behavior
- Success criteria: Graceful degradation, no timeouts > 5s

### Stress Test
- Increment: +50 users every minute until breaking point
- Purpose: Find maximum capacity
- Success criteria: Identify breaking point, document recovery behavior

### Chaos Test
- Baseline: 100 users
- Inject: Network latency, failure injection
- Purpose: Test resilience
- Success criteria: <5% error rate, recovery within 30s

### Multi-endpoint Test
- Mix of endpoints: 70% GET, 20% POST, 10% DELETE
- Represents production traffic pattern
- Success criteria: All endpoints meet SLOs
```

---

## Step 2: Write Gatling Load Tests

### 2.1 Gatling Test Structure

**File**: `bv-performance-testing/gatling-tests/src/test/scala/com/bitvelo/perf/OrderServiceLoadTest.scala`

```scala
package com.bitvelo.perf

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import java.util.UUID
import scala.concurrent.duration._

class OrderServiceLoadTest extends Simulation {
  
  val httpConf = http
    .baseUrl("http://orders-service:8080")
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")
    .userAgentHeader("Gatling Load Test")
    .disableCaching
    .shareConnections  // Reuse HTTP connections
  
  // Scenario 1: Create order (resource intensive)
  val createOrderScenario = scenario("Create Order")
    .exec(session =>
      session.set("customerId", UUID.randomUUID().toString)
    )
    .exec(
      http("POST Create Order")
        .post("/api/v1/orders")
        .header("Authorization", "Bearer ${token}")
        .body(StringBody("""
          {
            "customerId": "${customerId}",
            "items": [
              {"productId": "SKU-001", "quantity": 2}
            ]
          }
        """)).asJson
        .check(status.is(201))
        .check(jsonPath("$.orderId").exists)
        .responseTimeInMillis.lte(500)  // Assert p99 < 500ms
    )
  
  // Scenario 2: Get order (simple read)
  val getOrderScenario = scenario("Get Order")
    .exec(session =>
      session.set("orderId", "ORD-2024-00001")
    )
    .exec(
      http("GET Order Details")
        .get("/api/v1/orders/${orderId}")
        .header("Authorization", "Bearer ${token}")
        .check(status.is(200))
        .check(jsonPath("$.orderId").exists)
        .responseTimeInMillis.lte(250)  // Assert p95 < 250ms
    )
  
  // Scenario 3: Mixed traffic pattern
  val mixedTrafficScenario = scenario("Mixed Traffic")
    .exec(http("GET Products")
      .get("/api/v1/products")
      .check(status.is(200))
    )
    .pause(1)  // Think time
    .exec(http("POST Create Order")
      .post("/api/v1/orders")
      .body(StringBody("..."))
      .check(status.is(201))
    )
    .pause(2)
    .exec(http("GET Order")
      .get("/api/v1/orders/${orderId}")
      .check(status.is(200))
    )
  
  // Setup simulations
  setUp(
    // Baseline test
    createOrderScenario.inject(
      rampUsers(50).during(1.minute),  // Ramp to 50 users over 1 min
      holdFor(4.minutes),               // Hold at 50 for 4 min
      rampDown(30.seconds)              // Ramp down to 0
    )
//    .andThen(
//      // Soak test (after baseline completes)
//      mixedTrafficScenario.inject(
//        rampUsers(200).during(5.minutes),
//        holdFor(55.minutes)  // Hold for 1 hour total
//      )
//    )
  )
    .protocols(httpConf)
    .assertions(
      // Global assertions
      global.responseTime.percentile(95).lt(200),    // p95 < 200ms
      global.responseTime.percentile(99).lt(500),    // p99 < 500ms
      global.successfulRequests.percent.gt(99.9),    // > 99.9% success
      
      // Scenario-specific assertions
      details("POST Create Order")
        .responseTime.percentile(95).lt(300),
      details("GET Order Details")
        .responseTime.percentile(95).lt(150)
    )
    .maxDuration(10.minutes)  // Overall test timeout
}
```

### 2.2 Build.gradle for Gatling

```gradle
plugins {
  id 'io.gatling.gradle' version '3.10.5'
}

gatling {
  simulations {
    include 'com.bitvelo.perf.*LoadTest'  // Discover all tests
  }
}

dependencies {
  gatlingImplementation 'io.gatling:gatling-app:3.10.1'
  gatlingImplementation 'io.gatling:gatling-recorder:3.10.1'
  gatlingImplementation 'io.gatling.highcharts:gatling-charts-highcharts:3.10.1'
}

task gatlingReport {
  dependsOn gatlingRun
  doLast {
    println "Report generated: results/index.html"
  }
}
```

### 2.3 Running Gatling Tests

```bash
cd bv-performance-testing/gatling-tests

# Run all tests
./gradlew gatlingRun

# Run specific test
./gradlew gatlingRun -Dgatling.simulations.folder=src/test/scala/com/bitvelo/perf

# With custom settings
./gradlew gatlingRun \
  -Dgatling.simulation=com.bitvelo.perf.OrderServiceLoadTest \
  -Dgatling.results.folder=results \
  -Dgatling.chartsOnly

# Open HTML report
open build/reports/gatling/index.html
```

---

## Step 3: Write k6 Smoke Tests (CI)

### 3.1 k6 Test Script

**File**: `bv-performance-testing/k6-scripts/order-api-smoke-test.js`

```javascript
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import encoding from 'k6/encoding';

// Custom metrics
const errorRate = new Rate('errors');
const createOrderDuration = new Trend('create_order_duration');
const getOrderDuration = new Trend('get_order_duration');
const failedCreates = new Counter('failed_creates');

// Configure test
export const options = {
  stages: [
    { duration: '30s', target: 10 },      // Ramp-up
    { duration: '1m30s', target: 50 },    // Climb
    { duration: '20s', target: 0 },       // Ramp-down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<200', 'p(99)<500'],
    'http_req_failed': ['rate<0.001'],
    'errors': ['rate<0.001'],
  },
};

const API_URL = __ENV.API_URL || 'http://localhost:8080';
const TOKEN = __ENV.API_TOKEN || 'test-token';

// Helper: Generate auth header
function getAuthHeader() {
  return {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${TOKEN}`,
    },
  };
}

export default function() {
  // Group 1: Create Order
  group('Create Order', () => {
    const payload = JSON.stringify({
      customerId: `CUST-${__VU}-${__ITER}`,
      items: [
        {
          productId: 'SKU-001',
          quantity: Math.floor(Math.random() * 5) + 1,
        },
      ],
    });

    const res = http.post(
      `${API_URL}/api/v1/orders`,
      payload,
      getAuthHeader()
    );

    createOrderDuration.add(res.timings.duration);

    const success = check(res, {
      'Create order status is 201': (r) => r.status === 201,
      'Create order p95 < 200ms': (r) => r.timings.duration < 200,
      'Create order has orderId': (r) => r.json('orderId') !== undefined,
    });

    if (!success) {
      errorRate.add(1);
      failedCreates.add(1);
    }

    // Extract orderId for later use
    if (res.status === 201) {
      const orderId = res.json('orderId');
      
      sleep(1);  // Think time
      
      // Group 2: Get Order Details
      group('Get Order', () => {
        const getRes = http.get(
          `${API_URL}/api/v1/orders/${orderId}`,
          getAuthHeader()
        );

        getOrderDuration.add(getRes.timings.duration);

        const getSuccess = check(getRes, {
          'Get order status is 200': (r) => r.status === 200,
          'Get order p95 < 100ms': (r) => r.timings.duration < 100,
          'Get order matches orderId': (r) => r.json('orderId') === orderId,
        });

        if (!getSuccess) {
          errorRate.add(1);
        }
      });
    }
  });

  // Random think time (0-3 seconds)
  sleep(Math.random() * 3);
}

// Custom summary
export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'results.json': JSON.stringify(data),
  };
}

// Teardown: Validate results
export function teardown(data) {
  const summary = data;
  
  if (summary.metrics.errors.value > 0) {
    console.error(`FAILED: ${summary.metrics.errors.value} errors`);
    throw new Error('Smoke test failed');
  }
}
```

### 3.2 Running k6 Tests

```bash
cd bv-performance-testing/k6-scripts

# Run with environment
k6 run order-api-smoke-test.js \
  --vus 50 \
  --duration 5m \
  --env API_URL=http://orders-service:8080 \
  --env API_TOKEN=test-token

# Run with output to file
k6 run order-api-smoke-test.js \
  --out csv=results.csv \
  --out json=results.json

# Run in cloud (if licensed)
k6 cloud order-api-smoke-test.js
```

### 3.3 CI/CD Integration

Add to `.github/workflows/performance-test.yml`:

```yaml
name: Performance Tests

on: [push, pull_request]

jobs:
  k6-smoke-test:
    runs-on: ubuntu-latest
    services:
      orders-service:
        image: orders-service:latest
        ports:
          - 8080:8080
      postgres:
        image: postgres:15
        environment:
          POSTGRES_DB: orders
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3
      - uses: grafana/k6-action@v0.3.0
        with:
          filename: bv-performance-testing/k6-scripts/order-api-smoke-test.js
          cloud: false
        env:
          API_URL: http://localhost:8080

      - name: Fail if performance degraded
        if: failure()
        run: |
          echo "Performance test failed: p95 > threshold"
          exit 1

  gatling-load-test:
    runs-on: ubuntu-latest
    needs: k6-smoke-test  # Run after smoke test
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '21'

      - name: Run Gatling Load Tests
        run: |
          cd bv-performance-testing/gatling-tests
          ./gradlew gatlingRun

      - name: Upload Gatling Report
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: gatling-report
          path: build/reports/gatling/
```

---

## Step 4: Analyze Results

### 4.1 Gatling HTML Report

Automatically generated after test run:
- **Response times percentile**: p50, p75, p95, p99
- **Throughput**: Requests per second over time
- **Error rate**: Failed requests
- **Active users**: User count over time
- **Requests per second**: RPS trend

**Location**: `build/reports/gatling/index.html`

### 4.2 k6 Summary Output

```
          /\      |‾‾| /‾‾/   /‾‾/
     /\  /  \     |  |/  /   /  /
    /  \/    \    |     (   /   ‾‾\
   /          \   |  |\  \ |  (‾)  |
  / _________ \  |__| \_\_| \_____/ .io

  execution: local
  script: order-api-smoke-test.js
  output: csv (results.csv)

  scenarios: (100.00%) 1 scenario, 50 max VUs, 2m0s max duration
  create_order_duration..........: avg=180ms    min=45ms    med=170ms   max=350ms   p(95)=285ms  p(99)=320ms
  get_order_duration.............: avg=75ms     min=20ms    med=70ms    max=180ms   p(95)=130ms  p(99)=150ms
  http_req_duration..............: avg=127ms    min=20ms    med=110ms   max=350ms   p(95)=240ms  p(99)=300ms
  http_req_failed...............: 0.50%
  http_reqs......................: 2500 rate=20.83/sec
  http_req_tls_handshake_duration: avg=0ms min=0ms med=0ms max=0ms p(95)=0ms p(99)=0ms
  iteration_duration.............: avg=3.5s     min=2.1s    med=3.4s    max=5.2s    p(95)=4.8s   p(99)=5.1s
  iterations.....................: 500 rate=4.16/iter/s
  vus............................: 50 min=0 max=50
  vus_max........................: 50
```

### 4.3 Automated Analysis Script

**File**: `bv-performance-testing/analyze-results.py`

```python
import json
import csv
import sys

def analyze_gatling_results(results_json):
    with open(results_json) as f:
        data = json.load(f)
    
    # Extract metrics
    assertions = data.get('assertions', [])
    stats = data.get('stats', {})
    
    print("\n=== Performance Summary ===")
    for assertion in assertions:
        status = "✓ PASS" if assertion['result'] else "✗ FAIL"
        print(f"{status}: {assertion['message']}")
    
    # Check against SLOs
    SLO_P95 = 200  # ms
    SLO_ERROR_RATE = 0.001
    
    p95 = stats['response_time']['percentile_95']
    error_rate = stats['error_rate']
    
    print(f"\nLatency: p95={p95:.0f}ms (SLO: {SLO_P95}ms) {
        '✓' if p95 < SLO_P95 else '✗'
    }")
    print(f"Errors: {error_rate:.2%} (SLO: {SLO_ERROR_RATE:.2%}) {
        '✓' if error_rate < SLO_ERROR_RATE else '✗'
    }")
    
    return {"p95_ok": p95 < SLO_P95, "error_rate_ok": error_rate < SLO_ERROR_RATE}

if __name__ == "__main__":
    results = analyze_gatling_results(sys.argv[1])
    sys.exit(0 if all(results.values()) else 1)
```

---

## Step 5: Update Baselines

After each successful test run, update `sli-targets.yaml`:

```yaml
services:
  order-service:
    endpoints:
      POST /api/v1/orders:
        latency:
          p50: 50ms
          p95: 180ms      # Updated from 200ms based on test
          p99: 320ms      # Updated from 500ms
        throughput: 120 req/sec  # Updated
        last_tested: 2024-01-15
        test_result: PASS
        test_run_id: gatling-001
```

---

## Step 6: Continuous Monitoring

### 6.1 Dashboard Integration

Set up Prometheus/Grafana dashboards to monitor:
- p95, p99 latencies (from application metrics)
- Throughput
- Error rates
- Circuit breaker state
- Database connection pool
- Garbage collection pauses

### 6.2 Alerting Rules

```yaml
groups:
  - name: performance
    rules:
      - alert: HighLatency
        expr: histogram_quantile(0.95, http_request_duration_seconds) > 0.2
        for: 5m
        annotations:
          summary: "High latency detected: {{ $value }}s"

      - alert: HighErrorRate
        expr: rate(http_requests_failed_total[5m]) > 0.001
        for: 5m
        annotations:
          summary: "Error rate > 0.1%: {{ $value }}"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Verify service is running, check port mapping |
| High latency outliers | Check for GC pauses (enable GC logging), database slow queries |
| Failed requests | Check logs for exceptions, verify request format against contract |
| Memory leak suspected | Run soak test < 1h, monitor heap usage, check connections pool |
| k6 timeouts | Increase duration, reduce VUs, check network latency |

---

## References

- **Gatling Docs**: https://gatling.io/docs/
- **k6 Docs**: https://k6.io/docs/
- **SLI/SLO Guide**: `BitVelocity-Docs/docs/adr/ADR-015-load-testing-strategy.md`
- **Performance Baselines**: `bv-performance-testing/performance-baselines/sli-targets.yaml`
