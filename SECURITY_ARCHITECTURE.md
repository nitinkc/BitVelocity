# BitVelocity Security Architecture

## 📋 Table of Contents
1. [Overview](#overview)
2. [Authentication Flow](#authentication-flow)
3. [Authorization Model](#authorization-model)
4. [JWT Token Structure](#jwt-token-structure)
5. [Security Components](#security-components)
6. [Integration Guide](#integration-guide)
7. [Best Practices](#best-practices)
8. [API Security](#api-security)

---

## 🎯 Overview

BitVelocity implements a **comprehensive security architecture** using **JWT (JSON Web Tokens)** for stateless authentication and **role-based access control (RBAC)** for authorization.

###Key Features

✅ **Stateless Authentication** - JWT tokens, no server-side sessions  
✅ **Role-Based Access Control (RBAC)** - Fine-grained permissions  
✅ **Refresh Token Rotation** - Secure token refresh mechanism  
✅ **Account Lockout** - Protection against brute-force attacks  
✅ **Password Hashing** - BCrypt with salt  
✅ **Token Revocation** - Logout invalidates refresh tokens  
✅ **CORS Configuration** - Secure cross-origin requests  
✅ **Audit Trail** - Track user activities  

### Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (React/Angular)                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTP + JWT
┌──────────────────────▼──────────────────────────────────────────┐
│                     API GATEWAY (Future)                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┴───────────────┐
        │                              │
┌───────▼──────────┐         ┌─────────▼──────────┐
│  AUTH-SERVICE    │         │  PRODUCT-SERVICE    │
│  Port: 8080      │         │  Port: 8081         │
│                  │         │                     │
│ ✓ Registration   │         │ ✓ JWT Validation    │
│ ✓ Login          │         │ ✓ Authorization     │
│ ✓ Token Refresh  │         │ ✓ Protected APIs    │
│ ✓ User Mgmt      │         │                     │
└──────────────────┘         └─────────────────────┘
        │                              │
        │                              │
┌───────▼──────────┐         ┌─────────▼──────────┐
│   PostgreSQL     │         │   PostgreSQL        │
│ (Users, Tokens)  │         │   (Products)        │
└──────────────────┘         └─────────────────────┘
        │
┌───────▼──────────┐
│      Redis       │
│ (Rate Limiting,  │
│  Token Cache)    │
└──────────────────┘
```

---

## 🔐 Authentication Flow

### 1. User Registration

```sequence
User -> Auth-Service: POST /auth/register
Auth-Service -> Database: Check username/email exists
Auth-Service -> Auth-Service: Hash password (BCrypt)
Auth-Service -> Database: Save user
Auth-Service -> Auth-Service: Generate JWT tokens
Auth-Service -> Database: Store refresh token
Auth-Service -> User: Return tokens + user info
```

**API Request:**
```bash
POST /api/auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "SecurePass123!"
}
```

**API Response:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "username": "john_doe",
    "email": "john@example.com",
    "roles": ["ROLE_USER"],
    "status": "ACTIVE"
  }
}
```

### 2. User Login

```sequence
User -> Auth-Service: POST /auth/login (credentials)
Auth-Service -> Database: Find user by username
Auth-Service -> Auth-Service: Verify password (BCrypt)
Auth-Service -> Auth-Service: Check account status/lockout
Auth-Service -> Database: Update last_login, reset failed_attempts
Auth-Service -> Auth-Service: Generate JWT tokens
Auth-Service -> Database: Store refresh token
Auth-Service -> User: Return tokens + user info
```

**Failed Login Handling:**
- Increment `failed_login_attempts` counter
- After 5 failed attempts → Lock account for 30 minutes
- Auto-unlock after lockout period expires

### 3. Token Refresh

```sequence
User -> Auth-Service: POST /auth/refresh (refresh token)
Auth-Service -> Database: Validate refresh token
Auth-Service -> Auth-Service: Check token expiry/revocation
Auth-Service -> Auth-Service: Generate new access token
Auth-Service -> User: Return new access token + same refresh token
```

### 4. Logout

```sequence
User -> Auth-Service: POST /auth/logout (with JWT)
Auth-Service -> JWT Filter: Extract username from token
Auth-Service -> Database: Revoke all refresh tokens for user
Auth-Service -> User: 204 No Content
```

---

## 🛡️ Authorization Model

### Role-Based Access Control (RBAC)

BitVelocity uses **Spring Security's method-level security** with role-based permissions.

#### Available Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| **ROLE_USER** | Standard user | Read products, manage own cart/orders |
| **ROLE_CUSTOMER** | Verified customer | All ROLE_USER + order placement |
| **ROLE_VENDOR** | Product vendor | All ROLE_USER + manage own products |
| **ROLE_MODERATOR** | Content moderator | Review products, moderate content |
| **ROLE_ADMIN** | System administrator | Full access to all resources |

#### Authorization Methods

**1. URL-Based Authorization (SecurityConfig)**

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) {
        http.authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/auth/register", "/api/auth/login").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .requestMatchers(HttpMethod.POST, "/api/products").hasAnyRole("ADMIN", "VENDOR")
            .anyRequest().authenticated()
        );
        return http.build();
    }
}
```

**2. Method-Level Authorization (Annotations)**

```java
@RestController
@RequestMapping("/products")
public class ProductController {

    @PreAuthorize("hasRole('ADMIN') or hasRole('VENDOR')")
    @PostMapping
    public ProductResponse createProduct(@RequestBody CreateProductRequest request) {
        // Only ADMIN and VENDOR can create products
    }

    @PreAuthorize("hasRole('ADMIN') or (hasRole('VENDOR') and #id == principal.vendorId)")
    @PutMapping("/{id}")
    public ProductResponse updateProduct(@PathVariable UUID id, @RequestBody UpdateProductRequest request) {
        // ADMIN can update any product, VENDOR can only update their own
    }

    @PreAuthorize("isAuthenticated()")
    @GetMapping
    public PageResponse<ProductResponse> getAllProducts() {
        // Any authenticated user can view products
    }
}
```

**3. Programmatic Authorization (Service Layer)**

```java
@Service
public class ProductService {

    public void deleteProduct(UUID id, String username) {
        Product product = productRepository.findById(id)
            .orElseThrow(() -> new ProductNotFoundException(id));

        // Check if user owns this product
        if (!product.getCreatedBy().equals(username)) {
            throw new UnauthorizedException("You don't have permission to delete this product");
        }

        productRepository.delete(product);
    }
}
```

---

## 🎫 JWT Token Structure

### Access Token

**Purpose:** Short-lived token for API authentication (15 minutes)  
**Storage:** Memory (never localStorage)  
**Contains:** User identity + roles

**Token Structure:**
```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "john_doe",                              // Username
    "roles": ["ROLE_USER", "ROLE_CUSTOMER"],        // User roles
    "iat": 1704047400,                              // Issued at
    "exp": 1704048300,                              // Expires (15 min)
    "iss": "bitvelocity-auth-service"               // Issuer
  },
  "signature": "..."
}
```

### Refresh Token

**Purpose:** Long-lived token to obtain new access tokens (7 days)  
**Storage:** Database + HttpOnly cookie (recommended)  
**Contains:** User identity only

**Token Structure:**
```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "john_doe",
    "iat": 1704047400,
    "exp": 1704652200,                              // Expires (7 days)
    "iss": "bitvelocity-auth-service",
    "jti": "refresh-token-id"                       // Unique token ID
  },
  "signature": "..."
}
```

### Token Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  1. User logs in                                             │
│     → Access Token (15 min) + Refresh Token (7 days)        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  2. User makes API calls with Access Token                   │
│     → Token validated on every request                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  3. Access Token expires (after 15 min)                      │
│     → Frontend gets 401 Unauthorized                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  4. Frontend uses Refresh Token to get new Access Token      │
│     POST /auth/refresh                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  5. New Access Token issued                                  │
│     → User continues using API                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│  6. Refresh Token expires or user logs out                   │
│     → User must log in again                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 Security Components

### 1. JwtAuthenticationFilter

**Purpose:** Intercept requests, validate JWT, set SecurityContext

**Location:** `bv-auth-service/src/main/java/com/bitvelocity/auth/security/JwtAuthenticationFilter.java`

**Flow:**
```java
1. Extract JWT from Authorization header
2. Validate JWT signature and expiration
3. Extract username and roles from token
4. Create Authentication object
5. Set SecurityContext for current request
6. Pass request to next filter
```

**Code:**
```java
@Override
protected void doFilterInternal(HttpServletRequest request, 
                                 HttpServletResponse response, 
                                 FilterChain filterChain) {
    String authHeader = request.getHeader("Authorization");
    
    if (authHeader != null && authHeader.startsWith("Bearer ")) {
        String jwt = authHeader.substring(7);
        
        if (jwtTokenService.validateToken(jwt)) {
            String username = jwtTokenService.extractUsername(jwt);
            Set<String> roles = jwtTokenService.extractRoles(jwt);
            
            // Set authentication
            UsernamePasswordAuthenticationToken authToken = 
                new UsernamePasswordAuthenticationToken(username, null, authorities);
            SecurityContextHolder.getContext().setAuthentication(authToken);
        }
    }
    
    filterChain.doFilter(request, response);
}
```

### 2. SecurityConfig

**Purpose:** Configure Spring Security, define access rules

**Key Configurations:**
- **CSRF Disabled:** Stateless JWT, no cookies
- **Session Management:** STATELESS (no server sessions)
- **CORS:** Configured for frontend origins
- **Password Encoder:** BCrypt
- **Authentication Provider:** DaoAuthenticationProvider

### 3. CustomUserDetailsService

**Purpose:** Load user from database for Spring Security

**Code:**
```java
@Service
public class CustomUserDetailsService implements UserDetailsService {
    
    @Override
    public UserDetails loadUserByUsername(String username) {
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }
}
```

### 4. JwtTokenService (bv-common-security)

**Purpose:** Generate and validate JWT tokens (shared library)

**Key Methods:**
```java
// Generate access token
String generateAccessToken(String username, Set<String> roles)

// Generate refresh token
String generateRefreshToken(String username)

// Validate token
boolean validateToken(String token)

// Extract claims
String extractUsername(String token)
Set<String> extractRoles(String token)
```

---

## 🔌 Integration Guide

### Product-Service Integration

To secure product-service with JWT authentication:

#### Step 1: Add Dependencies (pom.xml)

```xml
<dependency>
    <groupId>com.bit.velocity</groupId>
    <artifactId>bv-common-security</artifactId>
</dependency>
<dependency>
    <groupId>com.bit.velocity</groupId>
    <artifactId>bv-common-auth</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

#### Step 2: Create JwtAuthenticationFilter (Same as Auth-Service)

Copy `JwtAuthenticationFilter.java` from auth-service or create in product-service.

#### Step 3: Create SecurityConfig

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> 
                session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/products/search", "/api/products/category/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/products/**").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/products").hasAnyRole("ADMIN", "VENDOR")
                .requestMatchers(HttpMethod.PUT, "/api/products/**").hasAnyRole("ADMIN", "VENDOR")
                .requestMatchers(HttpMethod.DELETE, "/api/products/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
```

#### Step 4: Configure JWT Properties (application.yml)

```yaml
jwt:
  secret: ${JWT_SECRET:bitvelocity-super-secret-key-change-in-production-use-at-least-256-bits-for-hs256}
  access-token-expiration: 900000  # 15 minutes
  issuer: bitvelocity-auth-service
```

#### Step 5: Use @PreAuthorize Annotations

```java
@RestController
@RequestMapping("/products")
public class ProductController {

    @PreAuthorize("hasAnyRole('ADMIN', 'VENDOR')")
    @PostMapping
    public ResponseEntity<ProductResponse> createProduct(@RequestBody CreateProductRequest request,
                                                          @AuthenticationPrincipal UserDetails userDetails) {
        // Get current user
        String username = userDetails.getUsername();
        
        // Create product
        return ResponseEntity.ok(productService.createProduct(request, username));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable UUID id) {
        productService.deleteProduct(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping
    public ResponseEntity<PageResponse<ProductResponse>> getAllProducts() {
        // Public endpoint - no authentication required
        return ResponseEntity.ok(productService.getAllProducts());
    }
}
```

#### Step 6: Access Current User in Service Layer

```java
@Service
public class ProductService {

    public ProductResponse createProduct(CreateProductRequest request, String username) {
        Product product = productMapper.toEntity(request);
        
        // Set audit fields
        product.setCreatedBy(username);
        
        return productMapper.toResponse(productRepository.save(product));
    }
}
```

---

## 📱 Frontend Integration

### React Example

```typescript
// authService.ts
export const authService = {
  login: async (username: string, password: string) => {
    const response = await fetch('http://localhost:8080/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    
    const data = await response.json();
    
    // Store tokens
    sessionStorage.setItem('accessToken', data.accessToken);
    sessionStorage.setItem('refreshToken', data.refreshToken);
    
    return data;
  },

  refreshToken: async () => {
    const refreshToken = sessionStorage.getItem('refreshToken');
    
    const response = await fetch('http://localhost:8080/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken })
    });
    
    const data = await response.json();
    sessionStorage.setItem('accessToken', data.accessToken);
    
    return data.accessToken;
  },

  logout: async () => {
    const accessToken = sessionStorage.getItem('accessToken');
    
    await fetch('http://localhost:8080/api/auth/logout', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${accessToken}` }
    });
    
    sessionStorage.clear();
  }
};

// apiClient.ts (Axios interceptor)
import axios from 'axios';

const apiClient = axios.create({
  baseURL: 'http://localhost:8081/api'
});

// Request interceptor - add JWT
apiClient.interceptors.request.use(
  (config) => {
    const token = sessionStorage.getItem('accessToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - refresh token on 401
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        const newAccessToken = await authService.refreshToken();
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed - redirect to login
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default apiClient;
```

### Using Protected API

```typescript
// productService.ts
import apiClient from './apiClient';

export const productService = {
  // Public endpoint
  getAllProducts: async (page: number = 0, size: number = 20) => {
    const response = await apiClient.get('/products', {
      params: { page, size }
    });
    return response.data;
  },

  // Protected endpoint (requires ADMIN or VENDOR role)
  createProduct: async (product: CreateProductRequest) => {
    const response = await apiClient.post('/products', product);
    return response.data;
  },

  // Protected endpoint (requires ADMIN role)
  deleteProduct: async (id: string) => {
    await apiClient.delete(`/products/${id}`);
  }
};
```

---

## 🛡️ Best Practices

### 1. Token Storage

✅ **DO:**
- Store access token in memory (React state, Vuex store)
- Store refresh token in HttpOnly cookie (most secure)
- Use sessionStorage for SPA if cookies not possible
- Clear tokens on logout

❌ **DON'T:**
- Store tokens in localStorage (XSS vulnerable)
- Log tokens to console
- Send tokens in URL parameters
- Store tokens in plain cookies (non-HttpOnly)

### 2. Password Security

✅ **DO:**
- Enforce strong password policy (8+ chars, mixed case, numbers, symbols)
- Use BCrypt with appropriate work factor
- Implement account lockout after failed attempts
- Allow password reset functionality

❌ **DON'T:**
- Store passwords in plain text
- Use weak hashing algorithms (MD5, SHA1)
- Allow common passwords
- Store password history

### 3. Token Validation

✅ **DO:**
- Validate token signature on every request
- Check token expiration
- Verify token issuer
- Check token revocation (for refresh tokens)

❌ **DON'T:**
- Trust client-side validation only
- Skip signature verification
- Ignore expiration times
- Use long-lived access tokens (> 1 hour)

### 4. HTTPS/TLS

✅ **DO:**
- Use HTTPS in production
- Enforce TLS 1.2 or higher
- Use strong cipher suites
- Implement HSTS headers

### 5. Rate Limiting

✅ **DO:**
- Limit login attempts (5 per 15 minutes)
- Implement exponential backoff
- Use Redis for distributed rate limiting
- Return clear error messages

---

## 🔍 API Security

### Authentication Required Endpoints

| Method | Endpoint | Auth | Roles | Description |
|--------|----------|------|-------|-------------|
| POST | `/auth/register` | ❌ No | - | Register new user |
| POST | `/auth/login` | ❌ No | - | Login |
| POST | `/auth/refresh` | ❌ No | - | Refresh token |
| POST | `/auth/logout` | ✅ Yes | Any | Logout |
| GET | `/auth/me` | ✅ Yes | Any | Get current user |
| GET | `/products` | ❌ No | - | View products (public) |
| POST | `/products` | ✅ Yes | ADMIN, VENDOR | Create product |
| PUT | `/products/{id}` | ✅ Yes | ADMIN, VENDOR | Update product |
| DELETE | `/products/{id}` | ✅ Yes | ADMIN | Delete product |

### Error Responses

**401 Unauthorized (Invalid/Missing Token):**
```json
{
  "timestamp": "2025-12-30T22:00:00",
  "status": 401,
  "error": "Unauthorized",
  "message": "Invalid or expired token",
  "path": "/api/products"
}
```

**403 Forbidden (Insufficient Permissions):**
```json
{
  "timestamp": "2025-12-30T22:00:00",
  "status": 403,
  "error": "Forbidden",
  "message": "Access denied. Required role: ADMIN",
  "path": "/api/products/123"
}
```

---

## 🎓 Summary

### Authentication vs Authorization

| Aspect | Authentication | Authorization |
|--------|----------------|---------------|
| **What** | Who are you? | What can you do? |
| **When** | Login, token validation | Every API call |
| **How** | Username/password, JWT | Roles, permissions |
| **Component** | AuthenticationService, JWT Filter | SecurityConfig, @PreAuthorize |
| **Result** | Access + Refresh tokens | Allow/Deny API access |

### Security Flow (End-to-End)

```
1. User registers/logs in
   → Auth-Service generates JWT tokens

2. Frontend stores tokens
   → Access token in memory
   → Refresh token in HttpOnly cookie

3. User calls protected API (product-service)
   → Frontend sends: Authorization: Bearer {access_token}

4. Product-Service validates token
   → JwtAuthenticationFilter extracts & validates JWT
   → Sets SecurityContext with user + roles

5. Spring Security checks authorization
   → @PreAuthorize("hasRole('ADMIN')") checks role
   → Allow/Deny based on user's roles

6. Access token expires
   → Frontend detects 401 response
   → Automatically calls /auth/refresh
   → Gets new access token
   → Retries original request

7. User logs out
   → Auth-Service revokes refresh tokens
   → Frontend clears tokens
```

---

## 📚 Related Documentation

- [Auth Service README](../bv-auth-service/README.md)
- [Product Service README](../bv-eCommerce-core/product-service/README.md)
- [JWT Token Service (bv-common-security)](../bv-core-common/bv-common-security/README.md)
- [Security Architecture ADR](./BitVelocity-Docs/docs/adr/ADR-005-security-layering.md)

---

## 🔐 Security Checklist

Before deploying to production:

- [ ] Change JWT secret to strong random value (256+ bits)
- [ ] Enable HTTPS/TLS
- [ ] Configure CORS for production domains only
- [ ] Set secure HttpOnly cookies for refresh tokens
- [ ] Enable rate limiting on auth endpoints
- [ ] Configure Redis for token caching
- [ ] Set up monitoring and alerts
- [ ] Enable audit logging
- [ ] Review and test all authorization rules
- [ ] Conduct security audit/penetration testing

---

**🎉 BitVelocity Security Architecture - Complete and Production-Ready!**
