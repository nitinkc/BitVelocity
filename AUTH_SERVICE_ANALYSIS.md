# Auth Service Analysis & Decision Guide

**Date**: December 30, 2025  
**Question**: Do we need `bv-auth-service` or is `bv-common-auth` enough?

---

## 🎯 TL;DR - The Answer

**YES, you need BOTH - they serve different purposes:**

| Component | Purpose | Location | Needs DB? |
|-----------|---------|----------|-----------|
| **`bv-common-auth`** | Shared library for **validating** tokens | Used by all services | ❌ No |
| **`bv-common-security`** | JWT utilities (token generation/validation) | Used by all services | ❌ No |
| **`bv-auth-service`** | Centralized **authentication** service | Standalone service | ✅ **YES** |

---

## 📦 What You Currently Have

### bv-common-auth (Library - No DB)

**Location**: `bv-core-common/bv-common-auth/`

**Current Files** (3 Java files):
```
├── UserContext.java          // POJO: userId, username, roles[]
├── SecurityContextHolder.java // ThreadLocal holder for UserContext
└── AuthUtils.java            // Utility methods
```

**Purpose**: 
- Provides **shared data structures** (UserContext)
- Provides **thread-local context** (SecurityContextHolder)
- Used by **downstream services** to access authenticated user info

**Does NOT**:
- ❌ Store users in database
- ❌ Issue JWT tokens
- ❌ Handle login/registration
- ❌ Validate passwords
- ❌ Manage sessions

### bv-common-security (Library - No DB)

**Location**: `bv-core-common/bv-common-security/`

**Current Files** (6 Java files):
```
├── jwt/
│   ├── JwtTokenService.java      // Token generation & validation
│   ├── JwtProperties.java        // Configuration (expiry, issuer, etc.)
│   └── JwtClaims.java            // JWT payload structure
└── password/
    ├── PasswordSecurityService.java  // BCrypt/Argon2 hashing
    └── PasswordValidationResult.java // Validation result POJO
```

**Purpose**:
- Provides **JWT token utilities** (generation, validation, parsing)
- Provides **password hashing utilities** (BCrypt, Argon2)
- Used by **auth-service** to create tokens
- Used by **all services** to validate tokens

**Does NOT**:
- ❌ Store users in database
- ❌ Expose REST endpoints
- ❌ Handle HTTP authentication flows
- ❌ Manage user lifecycle

### bv-auth-service (Microservice - NEEDS DB)

**Location**: `bv-auth-service/`

**Current State**: 🟡 Empty scaffold (7 starter files only)

**Purpose** (When Implemented):
- ✅ Exposes REST API endpoints: `/auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`
- ✅ Stores users in **database** (Postgres)
- ✅ Validates credentials (username/password)
- ✅ Generates JWT tokens (using `bv-common-security`)
- ✅ Manages user lifecycle (registration, password reset, account management)
- ✅ Enforces rate limiting, account lockout, MFA
- ✅ Stores refresh tokens in Redis
- ✅ Provides user profile management

---

## 🔄 How They Work Together

### Scenario 1: User Logs In

```
1. Frontend → bv-auth-service: POST /auth/login
   {
     "username": "john@example.com",
     "password": "SecurePassword123!"
   }

2. bv-auth-service:
   a. Queries database for user by username
   b. Uses PasswordSecurityService (from bv-common-security) to verify password
   c. Uses JwtTokenService (from bv-common-security) to generate access + refresh tokens
   d. Stores refresh token in Redis
   e. Returns tokens to frontend

3. Frontend receives:
   {
     "accessToken": "eyJhbGc...",
     "refreshToken": "eyJhbGc...",
     "expiresIn": 900
   }
```

### Scenario 2: User Accesses Product Service

```
1. Frontend → product-service: GET /api/products
   Headers: Authorization: Bearer eyJhbGc...

2. product-service:
   a. Extracts JWT from Authorization header
   b. Uses JwtTokenService (from bv-common-security) to validate token
   c. Parses UserContext (from bv-common-auth)
   d. Sets SecurityContextHolder.setContext(userContext)
   e. Processes request with user context
   f. Returns response

3. Throughout request lifecycle:
   - Controllers can access: SecurityContextHolder.getContext().getUserId()
   - Can check roles: userContext.getRoles() contains "ADMIN"
   - Can enforce authorization policies
```

### Scenario 3: Token Refresh

```
1. Frontend → bv-auth-service: POST /auth/refresh
   {
     "refreshToken": "eyJhbGc..."
   }

2. bv-auth-service:
   a. Validates refresh token (using JwtTokenService)
   b. Checks if token exists in Redis (not revoked)
   c. Generates new access token
   d. Returns new access token

3. Frontend updates stored access token
```

---

## 🗄️ Does Auth Service Need a Database?

### ✅ YES - Auth Service REQUIRES Database

**Reason**: Auth service must persist:

1. **User Accounts** (Postgres):
   ```sql
   CREATE TABLE users (
       id UUID PRIMARY KEY,
       username VARCHAR(255) UNIQUE NOT NULL,
       email VARCHAR(255) UNIQUE NOT NULL,
       password_hash VARCHAR(255) NOT NULL,
       roles VARCHAR[] NOT NULL,
       status VARCHAR(50) NOT NULL, -- ACTIVE, LOCKED, DISABLED
       failed_login_attempts INT DEFAULT 0,
       locked_until TIMESTAMP,
       created_at TIMESTAMP NOT NULL,
       updated_at TIMESTAMP NOT NULL
   );
   ```

2. **Refresh Tokens** (Redis):
   ```
   Key: refresh_token:{token_id}
   Value: {userId, issuedAt, expiresAt}
   TTL: 7 days (or configured refresh token expiry)
   ```

3. **User Sessions** (Redis - Optional):
   ```
   Key: user_session:{user_id}
   Value: {lastActivity, deviceInfo, ipAddress}
   TTL: Session timeout
   ```

4. **Rate Limiting** (Redis):
   ```
   Key: login_attempts:{ip_address}
   Value: attempt_count
   TTL: 15 minutes
   ```

### Database Schema (Postgres)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    roles VARCHAR[] NOT NULL DEFAULT ARRAY['USER'],
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    email_verified BOOLEAN DEFAULT FALSE,
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    version INT NOT NULL DEFAULT 0 -- Optimistic locking
);

-- Refresh tokens table (alternative to Redis)
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info VARCHAR(500),
    ip_address VARCHAR(45),
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    INDEX idx_user_id (user_id),
    INDEX idx_token_hash (token_hash),
    INDEX idx_expires_at (expires_at)
);

-- Audit log
CREATE TABLE auth_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL, -- LOGIN, LOGOUT, TOKEN_REFRESH, PASSWORD_RESET
    username VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_event_type (event_type)
);
```

---

## 🏗️ Auth Service Architecture

### Components Needed

```
bv-auth-service/
├── src/main/java/com/bitvelocity/auth/
│   ├── AuthServiceApplication.java       // Spring Boot main class
│   ├── controller/
│   │   ├── AuthController.java           // REST endpoints
│   │   └── UserController.java           // User management
│   ├── service/
│   │   ├── AuthenticationService.java    // Login/register logic
│   │   ├── TokenService.java             // Token management (uses JwtTokenService)
│   │   └── UserService.java              // User CRUD
│   ├── repository/
│   │   ├── UserRepository.java           // Spring Data JPA
│   │   └── RefreshTokenRepository.java
│   ├── entity/
│   │   ├── User.java                     // JPA entity
│   │   └── RefreshToken.java
│   ├── dto/
│   │   ├── LoginRequest.java
│   │   ├── RegisterRequest.java
│   │   ├── AuthResponse.java
│   │   └── UserResponse.java
│   ├── config/
│   │   ├── SecurityConfig.java           // Spring Security
│   │   ├── JpaConfig.java
│   │   └── RedisConfig.java
│   └── exception/
│       ├── InvalidCredentialsException.java
│       ├── UserAlreadyExistsException.java
│       └── AccountLockedException.java
└── src/main/resources/
    ├── application.yml
    └── db/migration/
        └── V1__create_users_table.sql    // Flyway migration
```

### Dependencies Needed

```xml
<dependencies>
    <!-- Shared BitVelocity libraries -->
    <dependency>
        <groupId>com.bit.velocity</groupId>
        <artifactId>bv-common-auth</artifactId>
    </dependency>
    <dependency>
        <groupId>com.bit.velocity</groupId>
        <artifactId>bv-common-security</artifactId>
    </dependency>
    <dependency>
        <groupId>com.bit.velocity</groupId>
        <artifactId>bv-common-exceptions</artifactId>
    </dependency>
    
    <!-- Spring Boot -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-security</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-redis</artifactId>
    </dependency>
    
    <!-- Database -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
    </dependency>
    <dependency>
        <groupId>org.flywaydb</groupId>
        <artifactId>flyway-core</artifactId>
    </dependency>
    
    <!-- Validation -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-validation</artifactId>
    </dependency>
</dependencies>
```

---

## 🔐 Auth Service Responsibilities

### Core Functions

1. **User Registration**
   - Validate email/username uniqueness
   - Hash password (using PasswordSecurityService from bv-common-security)
   - Store user in database
   - Send verification email (optional)

2. **User Login**
   - Validate credentials against database
   - Check account status (active, locked, disabled)
   - Enforce rate limiting (using Redis)
   - Generate access + refresh tokens
   - Record login in audit log

3. **Token Management**
   - Generate JWT access tokens (15 min expiry)
   - Generate refresh tokens (7 day expiry)
   - Store refresh tokens in Redis
   - Validate and refresh tokens
   - Revoke tokens on logout

4. **User Management**
   - Get user profile
   - Update user profile
   - Change password
   - Reset password (with email token)
   - Delete account

5. **Security Enforcement**
   - Rate limiting (login attempts)
   - Account lockout after failed attempts
   - Password complexity validation
   - Email verification (optional)
   - MFA support (future enhancement)

### REST Endpoints

```yaml
# OpenAPI spec outline
paths:
  /auth/register:
    post:
      summary: Register new user
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                username: string
                email: string
                password: string
                firstName: string
                lastName: string
      responses:
        '201': Created
        '400': Validation error
        '409': User already exists

  /auth/login:
    post:
      summary: Authenticate user
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                username: string
                password: string
      responses:
        '200': 
          content:
            application/json:
              schema:
                type: object
                properties:
                  accessToken: string
                  refreshToken: string
                  expiresIn: number
        '401': Invalid credentials
        '423': Account locked

  /auth/refresh:
    post:
      summary: Refresh access token
      requestBody:
        content:
          application/json:
            schema:
              type: object
              properties:
                refreshToken: string
      responses:
        '200': New access token
        '401': Invalid refresh token

  /auth/logout:
    post:
      summary: Logout user (revoke refresh token)
      security:
        - bearerAuth: []
      responses:
        '204': No content

  /auth/me:
    get:
      summary: Get current user profile
      security:
        - bearerAuth: []
      responses:
        '200': User profile
        '401': Unauthorized
```

---

## 🔗 How Other Services Use Auth

### Product Service Example

```java
@RestController
@RequestMapping("/api/products")
public class ProductController {
    
    @Autowired
    private ProductService productService;
    
    @GetMapping
    public ResponseEntity<List<Product>> getAllProducts() {
        // No authentication required for browsing
        return ResponseEntity.ok(productService.getAllProducts());
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<Product> getProduct(@PathVariable Long id) {
        // Uses UserContext from SecurityContextHolder (set by JWT filter)
        UserContext userContext = SecurityContextHolder.getContext();
        
        Product product = productService.getProduct(id, userContext);
        return ResponseEntity.ok(product);
    }
    
    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")  // Uses roles from JWT
    public ResponseEntity<Product> createProduct(@RequestBody ProductRequest request) {
        UserContext userContext = SecurityContextHolder.getContext();
        
        Product product = productService.createProduct(request, userContext);
        return ResponseEntity.status(HttpStatus.CREATED).body(product);
    }
}
```

### JWT Filter (in Product Service)

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    @Autowired
    private JwtTokenService jwtTokenService; // From bv-common-security
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                    HttpServletResponse response, 
                                    FilterChain filterChain) {
        String token = extractTokenFromHeader(request);
        
        if (token != null) {
            try {
                // Validate token using shared library
                UserContext userContext = jwtTokenService.extractUserContext(token);
                
                // Store in thread-local (from bv-common-auth)
                SecurityContextHolder.setContext(userContext);
                
            } catch (JwtException e) {
                // Token invalid - continue without authentication
                log.warn("Invalid JWT token: {}", e.getMessage());
            }
        }
        
        try {
            filterChain.doFilter(request, response);
        } finally {
            // Always clear context after request
            SecurityContextHolder.clearContext();
        }
    }
}
```

---

## 🚀 Implementation Priority

### Phase 1: Foundation (Do This First)

**Before implementing auth-service**, ensure you have:

1. ✅ `bv-core-common` built and published
2. ✅ `bv-common-security` JWT utilities working
3. ✅ `bv-common-auth` context classes ready
4. ✅ Docker Compose with Postgres + Redis

### Phase 2: Auth Service (Phase 3 in Roadmap)

Implement auth-service **after** you have:

1. ✅ At least one working service (`product-service`)
2. ✅ Understanding of Spring Boot patterns
3. ✅ Basic REST API experience

**Why wait?**
- Auth is complex (security, tokens, sessions)
- Better to learn Spring Boot with simpler service first
- Can manually create tokens for testing initially
- Auth service benefits from learned patterns

### Phase 3: Integrate Auth

Once auth-service is working:

1. Add JWT filter to all services
2. Test authentication flows
3. Add role-based authorization
4. Implement audit logging

---

## 🎯 Recommendation

### ✅ KEEP bv-auth-service

**Reasons**:
1. **Centralized user management** - Single source of truth for users
2. **Security boundary** - Isolates credential validation
3. **Scalability** - Can scale independently of business services
4. **Auditability** - All auth events in one place
5. **Standard pattern** - Industry best practice (OAuth2 / OpenID Connect style)

### ⚠️ DO NOT Try to Use Only bv-common-auth

**Why it won't work**:
- Libraries can't expose REST endpoints
- Libraries can't store data in database
- Libraries can't manage user lifecycle
- Libraries can't enforce rate limiting or account lockout

### 📋 Summary Table

| Feature | bv-common-auth | bv-common-security | bv-auth-service |
|---------|----------------|-------------------|-----------------|
| Store users | ❌ | ❌ | ✅ |
| Validate password | ❌ | ✅ (utilities) | ✅ (uses utilities) |
| Generate JWT | ❌ | ✅ (utilities) | ✅ (uses utilities) |
| Validate JWT | ❌ | ✅ | ✅ |
| REST endpoints | ❌ | ❌ | ✅ |
| User registration | ❌ | ❌ | ✅ |
| User login | ❌ | ❌ | ✅ |
| Token refresh | ❌ | ❌ | ✅ |
| Rate limiting | ❌ | ❌ | ✅ |
| Audit logging | ❌ | ❌ | ✅ |
| Needs database | ❌ | ❌ | ✅ **YES** |
| Used by | All services | All services + auth-service | Frontend |

---

## 📝 Next Steps

1. **Immediate**: Focus on `product-service` first (simpler)
2. **Week 3-4**: Implement `bv-auth-service` following [Phase 3 guide](BitVelocity-Docs/docs/stories/phases/PHASE-3.md)
3. **Week 5**: Integrate JWT filters into existing services
4. **Week 6**: Add role-based authorization

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for detailed implementation sequence.

---

**Conclusion**: You need ALL THREE components. They work together:
- **bv-common-auth**: Shared data structures
- **bv-common-security**: JWT utilities (no HTTP, no DB)
- **bv-auth-service**: Full authentication service (with DB, REST endpoints, user management)
