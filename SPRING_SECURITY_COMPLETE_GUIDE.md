# Spring Security Complete Guide - BitVelocity

> **Purpose**: A comprehensive, systematic guide to understanding Spring Security implementation in BitVelocity, covering authentication, authorization, JWT, password management, and database integration.

**Last Updated**: December 31, 2025  
**Version**: 1.0

---

## Table of Contents

1. [Introduction to Spring Security](#1-introduction-to-spring-security)
2. [Spring Security Architecture Overview](#2-spring-security-architecture-overview)
3. [Security Filter Chain Deep Dive](#3-security-filter-chain-deep-dive)
4. [Authentication Fundamentals](#4-authentication-fundamentals)
5. [Authorization and Access Control](#5-authorization-and-access-control)
6. [JWT Token Implementation](#6-jwt-token-implementation)
7. [Password Security](#7-password-security)
8. [Database Integration for User Management](#8-database-integration-for-user-management)
9. [Custom Security Components](#9-custom-security-components)
10. [Session Management](#10-session-management)
11. [CORS and CSRF Configuration](#11-cors-and-csrf-configuration)
12. [Security Best Practices](#12-security-best-practices)
13. [BitVelocity Implementation Reference](#13-bitvelocity-implementation-reference)
14. [Common Patterns and Anti-Patterns](#14-common-patterns-and-anti-patterns)
15. [Testing Security](#15-testing-security)
16. [Troubleshooting Guide](#16-troubleshooting-guide)

---

## 1. Introduction to Spring Security

### 1.1 What is Spring Security?
Servlet filter-based framework providing authentication, authorization, and protection against common exploits. Integrates seamlessly with Spring Boot via auto-configuration.

### 1.2 Core Concepts
- **Authentication**: Verifying identity (who you are)
- **Authorization**: Verifying permissions (what you can do)
- **Principal**: Currently authenticated user
- **GrantedAuthority**: Permissions/roles assigned to principal
- **SecurityContext**: Holds authentication object for current thread

### 1.3 Security Goals
- Stateless JWT-based auth (no server sessions)
- Fine-grained RBAC with method-level security
- Secure password storage (BCrypt hashing)
- Token refresh mechanism
- Account lockout protection
- Audit trail for security events

### 1.4 When to Use Spring Security
Use when you need enterprise-grade security with minimal boilerplate. Overkill for public APIs with no auth requirements.

### 1.5 BitVelocity Security Requirements
- Multi-service architecture with centralized auth
- JWT tokens for inter-service communication
- Shared security libraries (`bv-common-auth`, `bv-common-security`)
- Database-backed user management
- Role-based access (USER, CUSTOMER, VENDOR, MODERATOR, ADMIN)

---

## 2. Spring Security Architecture Overview

### 2.1 High-Level Architecture
```
HTTP Request → Filter Chain → DispatcherServlet → Controller
                    ↓
           JWT Filter extracts token
                    ↓
           Validates & sets SecurityContext
                    ↓
           Controller accesses Principal
```

### 2.2 Security Context
Thread-local storage holding `Authentication` object for current request. Access via `SecurityContextHolder.getContext().getAuthentication()`.

### 2.3 Authentication Manager
Delegates to one or more `AuthenticationProvider`s. Tries each until one succeeds or all fail.

### 2.4 Authentication Provider
`DaoAuthenticationProvider` in BitVelocity: loads user from DB via `UserDetailsService`, compares password using `PasswordEncoder`.

### 2.5 UserDetailsService
Contract: `loadUserByUsername(String) → UserDetails`. BitVelocity's `CustomUserDetailsService` queries `UserRepository`.

### 2.6 PasswordEncoder
`BCryptPasswordEncoder` hashes passwords with salt. Never stores plain text. Encoding happens once (registration); verification happens each login.

### 2.7 Security Filter Chain
Ordered list of filters. Custom JWT filter inserted before `UsernamePasswordAuthenticationFilter` to intercept and validate tokens.

### 2.8 How Components Work Together
1. Request hits JWT filter → extracts token
2. JWT filter validates token → extracts user info
3. Creates `Authentication` object → sets in `SecurityContext`
4. Request proceeds to controller with authenticated principal
5. Authorization checks (method/URL-level) use `Authentication.authorities`
6. After response, `SecurityContext` cleared to prevent leaks

---

## 3. Security Filter Chain Deep Dive

### 3.1 What is a Filter Chain?
Servlet filters wrapping the request/response pipeline. Each filter can inspect, modify, or block requests before reaching controllers.

### 3.2 Order of Filters
Order matters. Spring Security maintains ~15 default filters. Custom filters inserted at specific positions.

### 3.3 Built-in Security Filters

#### 3.3.1 SecurityContextPersistenceFilter
Loads/saves `SecurityContext` from session (stateful) or creates empty context (stateless).

#### 3.3.2 UsernamePasswordAuthenticationFilter
Intercepts `/login` POST, extracts username/password, authenticates via `AuthenticationManager`. Not used in JWT flow.

#### 3.3.3 BasicAuthenticationFilter
Handles HTTP Basic auth (`Authorization: Basic base64(user:pass)`). Not used in BitVelocity.

#### 3.3.4 ExceptionTranslationFilter
Catches security exceptions, converts to HTTP 401/403 responses.

#### 3.3.5 FilterSecurityInterceptor
Final filter, enforces URL-based authorization rules from `SecurityFilterChain` config.

### 3.4 Custom Filters

#### 3.4.1 Creating Custom Filters
Extend `OncePerRequestFilter` (guarantees single execution per request, handles async/error dispatch).

#### 3.4.2 Filter Positioning
Insert custom filter:
```java
.addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
```

#### 3.4.3 OncePerRequestFilter
BitVelocity's `JwtAuthenticationFilter` extends this. Ensures filter runs exactly once even with forward/error dispatches.

### 3.5 JWT Authentication Filter (BitVelocity Implementation)
```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(request, response, chain) {
        String token = extractToken(request); // From Authorization header
        if (token != null && !jwtTokenService.isTokenExpired(token)) {
            UserContext userContext = jwtTokenService.extractUserContext(token);
            setSpringSecurityContext(userContext); // Create Authentication
            SecurityContextHolder.setUserContext(userContext); // Custom context
        }
        chain.doFilter(request, response); // Continue chain
        SecurityContextHolder.clear(); // Cleanup
    }
}
```

### 3.6 Filter Chain Execution Flow
1. **Request arrives** → enters filter chain
2. **JWT Filter** → validates token, sets context
3. **ExceptionTranslationFilter** → wraps downstream filters
4. **FilterSecurityInterceptor** → checks authorization
5. **DispatcherServlet** → routes to controller
6. **Response** → filters execute in reverse (cleanup)
7. **SecurityContext cleared** → prevents thread-local leaks

---

## 4. Authentication Fundamentals

### 4.1 What is Authentication?
Process of verifying identity. Answers "Who are you?" by validating credentials (password, token, certificate, etc.).

### 4.2 Authentication Flow
```
1. User submits credentials
2. AuthenticationManager receives request
3. DaoAuthenticationProvider loads user via UserDetailsService
4. PasswordEncoder verifies password
5. Success: Authentication object created with authorities
6. Failure: BadCredentialsException thrown
7. SecurityContext populated with Authentication
```

### 4.3 Authentication Object
Holds:
- `principal` (UserDetails or username)
- `credentials` (password, cleared after auth)
- `authorities` (roles/permissions)
- `authenticated` flag

### 4.4 Principal, Credentials, Authorities
- **Principal**: User object (can be `UserDetails` or simple String)
- **Credentials**: Password (removed post-auth for security)
- **Authorities**: List of `GrantedAuthority` (roles like `ROLE_ADMIN`)

### 4.5 UserDetails Interface
Contract for user info:
```java
interface UserDetails {
    String getUsername();
    String getPassword();
    Collection<? extends GrantedAuthority> getAuthorities();
    boolean isAccountNonExpired();
    boolean isAccountNonLocked();
    boolean isCredentialsNonExpired();
    boolean isEnabled();
}
```

### 4.6 UserDetailsService Implementation
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
BitVelocity's `User` entity implements `UserDetails` directly.

### 4.7 Custom UserDetailsService (BitVelocity)
Located in `bv-auth-service`. Queries `UserRepository` (JPA). Returns `User` entity which implements `UserDetails`.

### 4.8 Authentication Manager Configuration
```java
@Bean
public AuthenticationManager authenticationManager(AuthenticationConfiguration config) {
    return config.getAuthenticationManager();
}
```
Auto-configured by Spring, uses registered `AuthenticationProvider`s.

### 4.9 DaoAuthenticationProvider
```java
@Bean
public AuthenticationProvider authenticationProvider() {
    DaoAuthenticationProvider provider = new DaoAuthenticationProvider(userDetailsService);
    provider.setPasswordEncoder(passwordEncoder());
    return provider;
}
```
Combines `UserDetailsService` + `PasswordEncoder` for DB-backed auth.

### 4.10 Authentication Success vs Failure
- **Success**: `Authentication` object created, stored in `SecurityContext`
- **Failure**: Exception thrown (`BadCredentialsException`, `UsernameNotFoundException`, `AccountLockedException`)

### 4.11 Storing Authentication in Security Context
```java
// Manual (in filters)
Authentication auth = new UsernamePasswordAuthenticationToken(userDetails, null, authorities);
SecurityContextHolder.getContext().setAuthentication(auth);

// Auto (via AuthenticationManager)
Authentication auth = authenticationManager.authenticate(
    new UsernamePasswordAuthenticationToken(username, password)
);
SecurityContextHolder.getContext().setAuthentication(auth);
```

---

## 5. Authorization and Access Control

### 5.1 Authentication vs Authorization
- **Authentication**: Identity verification (login)
- **Authorization**: Permission check (access control)

First authenticate, then authorize each request.

### 5.2 Role-Based Access Control (RBAC)
Users assigned roles (`ROLE_USER`, `ROLE_ADMIN`). Roles grant broad permissions. Simple but coarse-grained.

### 5.3 Permission-Based Access Control
Granular permissions (`READ_PRODUCT`, `WRITE_ORDER`). More flexible, complex to manage. BitVelocity uses hybrid (roles + permissions in JWT).

### 5.4 GrantedAuthority Interface
Represents permission/role:
```java
interface GrantedAuthority {
    String getAuthority(); // "ROLE_ADMIN" or "READ_PRODUCT"
}
```
Spring convention: roles prefixed with `ROLE_`.

### 5.5 URL-Based Authorization

#### 5.5.1 requestMatchers()
```java
.requestMatchers("/api/admin/**").hasRole("ADMIN")
.requestMatchers("/api/auth/**").permitAll()
```
Path patterns: Ant-style (`**` = any path, `*` = single segment).

#### 5.5.2 permitAll()
Allows unauthenticated access. Use for login, register, public endpoints.

#### 5.5.3 authenticated()
Requires any authenticated user (any role).

#### 5.5.4 hasRole() / hasAuthority()
- `hasRole("ADMIN")` checks for `ROLE_ADMIN`
- `hasAuthority("ROLE_ADMIN")` checks exact string

#### 5.5.5 hasAnyRole() / hasAnyAuthority()
Multiple roles: `hasAnyRole("ADMIN", "MODERATOR")`.

### 5.6 Method-Level Security

#### 5.6.1 @EnableMethodSecurity
```java
@EnableMethodSecurity(securedEnabled = true, jsr250Enabled = true)
```
Enables `@PreAuthorize`, `@Secured`, `@RolesAllowed`.

#### 5.6.2 @PreAuthorize
```java
@PreAuthorize("hasRole('ADMIN') or #userId == principal.userId")
public void updateUser(String userId) { }
```
SpEL expressions evaluated before method execution.

#### 5.6.3 @PostAuthorize
Checks authorization after method execution. Useful for filtering return values.

#### 5.6.4 @Secured
```java
@Secured("ROLE_ADMIN")
public void deleteUser() { }
```
Simpler than `@PreAuthorize`, no SpEL.

#### 5.6.5 @RolesAllowed
JSR-250 standard, equivalent to `@Secured`.

#### 5.6.6 SpEL Expressions
```java
@PreAuthorize("hasRole('VENDOR') and #productId == principal.vendorId")
@PreAuthorize("hasAnyRole('ADMIN', 'MODERATOR')")
@PreAuthorize("isAuthenticated() and #order.userId == principal.userId")
```

### 5.7 Custom Authorization Logic
Implement `PermissionEvaluator` for complex business logic:
```java
@PreAuthorize("hasPermission(#order, 'WRITE')")
```

### 5.8 BitVelocity Role Hierarchy
```
ROLE_ADMIN (full access)
  ↓
ROLE_MODERATOR (content management)
  ↓
ROLE_VENDOR (product management)
  ↓
ROLE_CUSTOMER (order placement)
  ↓
ROLE_USER (read-only)
```

---

## 6. JWT Token Implementation

### 6.1 Why JWT for Stateless Authentication?
- **No server state**: No session storage, scales horizontally
- **Self-contained**: Token carries all user info
- **Microservices**: Services independently verify tokens
- **Mobile-friendly**: Token stored client-side

### 6.2 JWT Structure (Header, Payload, Signature)
```
header.payload.signature

Header: {"alg":"HS256","typ":"JWT"}
Payload: {"userId":"123","username":"john","roles":["ROLE_USER"],"exp":1735680000}
Signature: HMACSHA256(base64(header)+"."+base64(payload), secret)
```
Signature prevents tampering. Anyone can read payload (it's base64, not encrypted).

### 6.3 JWT vs Session-Based Auth
| JWT | Session |
|-----|---------|
| Stateless | Stateful |
| Stored client-side | Stored server-side |
| No DB lookup per request | DB/Redis lookup per request |
| Can't revoke until expiry* | Instant revocation |
| Larger payload in requests | Small session ID |

*BitVelocity uses refresh token registry for revocation.

### 6.4 Token Generation

#### 6.4.1 Access Tokens
Short-lived (15 min). Used for API requests. Contains user ID, username, roles, permissions.

#### 6.4.2 Refresh Tokens
Long-lived (7 days). Used to obtain new access tokens. Stored in DB for revocation.

#### 6.4.3 Token Claims
```java
JwtClaims {
    String userId;
    String username;
    String email;
    Set<String> roles;
    Set<String> permissions;
    String tenantId;
    String tokenType; // "access" or "refresh"
}
```

#### 6.4.4 Token Expiration
Configured in `application.yml`:
```yaml
jwt:
  access-token-expiry: 15m
  refresh-token-expiry: 7d
  issuer: bitvelocity
  audience: bitvelocity-services
```

### 6.5 Token Validation

#### 6.5.1 Signature Verification
`Jwts.parserBuilder().setSigningKey(secret).build().parseClaimsJws(token)`
Throws `SecurityException` if signature invalid.

#### 6.5.2 Expiration Check
Checks `exp` claim. Throws `ExpiredJwtException` if expired.

#### 6.5.3 Issuer/Audience Validation
```java
.requireIssuer("bitvelocity")
.requireAudience("bitvelocity-services")
```
Prevents token reuse from other systems.

#### 6.5.4 Clock Skew Handling
```java
.setAllowedClockSkewSeconds(60) // Tolerate 1 min difference
```
Handles time sync issues across services.

### 6.6 Token Refresh Mechanism
```
1. Client sends expired access token + valid refresh token
2. Server validates refresh token (signature, expiry, not revoked)
3. Server generates new access token (same user context)
4. Server returns new access token (reuses refresh token)
```

Optional: Rotate refresh token on each use for better security.

### 6.7 Token Storage

#### 6.7.1 Client-Side Storage
- **localStorage**: Vulnerable to XSS
- **sessionStorage**: Cleared on tab close
- **Memory**: Lost on refresh
- **HttpOnly cookie**: Best for refresh tokens (XSS-safe, CSRF risk)

BitVelocity: Access token in memory, refresh token in HttpOnly cookie.

#### 6.7.2 Server-Side Token Registry
Refresh tokens stored in DB (`RefreshToken` entity) for revocation tracking.

#### 6.7.3 Redis for Refresh Tokens
Optional: Store refresh tokens in Redis with TTL for faster lookups and auto-expiry.

### 6.8 Token Revocation
On logout: Delete refresh token from DB. Access token still valid until expiry (trade-off for statelessness).

Mitigation: Short access token expiry (15 min).

### 6.9 JwtTokenService Implementation (bv-common-security)
```java
@Service
public class JwtTokenService {
    public String generateAccessToken(UserContext context) {
        return Jwts.builder()
            .setSubject(context.getUsername())
            .claim("userId", context.getUserId())
            .claim("roles", context.getRoles())
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + accessTokenExpiry))
            .signWith(getSigningKey(), SignatureAlgorithm.HS256)
            .compact();
    }
    
    public JwtClaims validateToken(String token) {
        Claims claims = Jwts.parserBuilder()
            .setSigningKey(getSigningKey())
            .setAllowedClockSkewSeconds(60)
            .build()
            .parseClaimsJws(token)
            .getBody();
        return mapToJwtClaims(claims);
    }
}
```

### 6.10 JWT Properties Configuration
```java
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {
    private String secret; // Base64-encoded 256-bit key
    private Duration accessTokenExpiry;
    private Duration refreshTokenExpiry;
    private String issuer;
    private String audience;
    private Duration clockSkew;
}
```

### 6.11 Security Considerations
- **Strong secret**: 256+ bit, random, never commit to git
- **HTTPS only**: Tokens interceptable over HTTP
- **Short expiry**: Limit damage window if token stolen
- **Audience claim**: Prevent token reuse across systems
- **Don't log tokens**: Sensitive data in logs = security breach

---

## 7. Password Security

### 7.1 Password Hashing Basics
One-way function: `hash(password) → hash`. Cannot reverse. Same password always produces same hash (with same salt).

### 7.2 Why Not Plain Text or MD5?
- **Plain text**: Instant compromise on breach
- **MD5**: Fast to crack, collision attacks, no salt
- **SHA-256**: Too fast, no salt, vulnerable to rainbow tables
- **BCrypt**: Slow by design, auto-salted, configurable cost

### 7.3 BCrypt Algorithm

#### 7.3.1 How BCrypt Works
Based on Blowfish cipher. Deliberately slow (adjustable). Includes random salt in output.

Output format: `$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy`
- `$2a$`: BCrypt version
- `10`: Cost factor (2^10 rounds)
- Next 22 chars: Salt (base64)
- Remaining: Hash (base64)

#### 7.3.2 Salt Generation
Random 128-bit value per password. Prevents rainbow table attacks. Stored with hash (not separately).

#### 7.3.3 Work Factor (Cost)
Cost = log2(rounds). Cost of 10 = 1024 rounds. Each increment doubles time.

Recommendation: 10-12 for production (balance security vs performance).

### 7.4 PasswordEncoder Interface
```java
interface PasswordEncoder {
    String encode(CharSequence rawPassword);
    boolean matches(CharSequence rawPassword, String encodedPassword);
    boolean upgradeEncoding(String encodedPassword); // Optional
}
```

### 7.5 BCryptPasswordEncoder Configuration
```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(); // Default cost = 10
    // new BCryptPasswordEncoder(12); // Higher security, slower
}
```

### 7.6 Password Encoding on Registration
```java
@Transactional
public AuthResponse register(RegisterRequest request) {
    User user = User.builder()
        .username(request.getUsername())
        .password(passwordEncoder.encode(request.getPassword())) // Hash here
        .build();
    userRepository.save(user);
}
```
Never store raw password. Encode immediately before persistence.

### 7.7 Password Verification on Login
```java
// Automatic via DaoAuthenticationProvider
authenticationManager.authenticate(
    new UsernamePasswordAuthenticationToken(username, password)
);
// Internally calls passwordEncoder.matches(rawPassword, hashedPassword)
```

Manual verification:
```java
boolean valid = passwordEncoder.matches(rawPassword, user.getPassword());
```

### 7.8 Password Complexity Requirements
BitVelocity rules:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 digit
- At least 1 special character

### 7.9 Password Validation Service (bv-common-security)
```java
@Service
public class PasswordSecurityService {
    public PasswordValidationResult validatePasswordComplexity(String password) {
        List<String> errors = new ArrayList<>();
        if (password.length() < 8) errors.add("Too short");
        if (!UPPERCASE_PATTERN.matcher(password).matches()) errors.add("No uppercase");
        // ... more checks
        return new PasswordValidationResult(errors.isEmpty(), errors);
    }
}
```

### 7.10 Password Reset Flow
```
1. User requests reset → email sent with signed token
2. User clicks link → verifies token (time-limited, single-use)
3. User submits new password
4. Server validates token, hashes new password, updates DB
5. Server invalidates reset token
```

### 7.11 Account Lockout Mechanism
```java
private void handleFailedLoginAttempt(User user) {
    user.incrementFailedAttempts();
    if (user.getFailedLoginAttempts() >= maxFailedAttempts) {
        user.setStatus(AccountStatus.LOCKED);
        user.setLockedUntil(LocalDateTime.now().plusMinutes(lockoutDurationMinutes));
    }
    userRepository.save(user);
}
```
After 5 failed attempts: lock for 30 minutes. Auto-unlocks after timeout.

### 7.12 Password Best Practices
- **Never log passwords**: Not even in debug mode
- **Use HTTPS**: Passwords over HTTP = plain text
- **Short token expiry**: Reset tokens valid 1 hour max
- **Rate limiting**: Prevent brute force on login endpoint
- **Password history**: Prevent reuse of last N passwords
- **MFA**: Consider for high-value accounts

---

## 8. Database Integration for User Management

### 8.1 User Entity Design

#### 8.1.1 JPA Entity Annotations
```java
@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_user_username", columnList = "username", unique = true),
    @Index(name = "idx_user_email", columnList = "email", unique = true)
})
@EntityListeners(AuditingEntityListener.class)
public class User implements UserDetails {
```
Indexes on username/email for fast lookups. Audit listener for created/updated timestamps.

#### 8.1.2 UserDetails Implementation
```java
@Override
public Collection<? extends GrantedAuthority> getAuthorities() {
    return roles.stream()
        .map(role -> new SimpleGrantedAuthority(role.name()))
        .collect(Collectors.toSet());
}
```
Entity implements `UserDetails` → works directly with Spring Security.

#### 8.1.3 UUID vs Long for Primary Key
BitVelocity uses UUID: No sequential enumeration, distributed-system-friendly, no DB auto-increment dependency.

#### 8.1.4 Indexing Strategy
- Username: Unique index (login lookup)
- Email: Unique index (password reset, notifications)
- Status: Index (filter active/locked accounts)

### 8.2 User Repository (JPA)
```java
public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByUsername(String username);
    Optional<User> findByEmail(String email);
    boolean existsByUsername(String username);
    boolean existsByEmail(String email);
}
```
Spring Data JPA generates SQL from method names.

### 8.3 Storing Password Hashes
```java
@Column(name = "password_hash", nullable = false)
private String password; // Field named "password" for Spring Security compatibility
```
Column named `password_hash` in DB, but Java field is `password` (Spring Security expects `getPassword()`).

### 8.4 User Roles Storage

#### 8.4.1 Enum vs Table-Based
BitVelocity uses enum (`Role.ROLE_USER`, `Role.ROLE_ADMIN`) for fixed roles. For dynamic roles, use many-to-many with `roles` table.

#### 8.4.2 @ElementCollection
```java
@ElementCollection(fetch = FetchType.EAGER)
@CollectionTable(name = "user_roles", joinColumns = @JoinColumn(name = "user_id"))
@Enumerated(EnumType.STRING)
@Column(name = "role")
private Set<Role> roles;
```
Creates `user_roles` table with `user_id` and `role` columns. EAGER fetch loads roles with user.

#### 8.4.3 Many-to-Many Relationship
For complex permission systems:
```java
@ManyToMany(fetch = FetchType.EAGER)
@JoinTable(name = "user_roles",
    joinColumns = @JoinColumn(name = "user_id"),
    inverseJoinColumns = @JoinColumn(name = "role_id"))
private Set<Role> roles;
```

### 8.5 Account Status Management
```java
@Enumerated(EnumType.STRING)
@Column(name = "status", nullable = false)
private AccountStatus status; // ACTIVE, LOCKED, DISABLED, PENDING_VERIFICATION

@Override
public boolean isEnabled() {
    return status == AccountStatus.ACTIVE;
}
```

### 8.6 Failed Login Attempts Tracking
```java
@Column(name = "failed_login_attempts", nullable = false)
private Integer failedLoginAttempts = 0;

public void incrementFailedAttempts() {
    this.failedLoginAttempts++;
}

public void resetFailedAttempts() {
    this.failedLoginAttempts = 0;
    this.lockedUntil = null;
}
```

### 8.7 Account Lockout Implementation
```java
@Column(name = "locked_until")
private LocalDateTime lockedUntil;

@Override
public boolean isAccountNonLocked() {
    if (status == AccountStatus.LOCKED && lockedUntil != null) {
        return LocalDateTime.now().isAfter(lockedUntil); // Auto-unlock
    }
    return status != AccountStatus.LOCKED;
}
```
Lockout expires automatically when current time > `lockedUntil`.

### 8.8 Refresh Token Storage

#### 8.8.1 RefreshToken Entity
```java
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    
    @Column(nullable = false, unique = true)
    private String token;
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    
    @Column(nullable = false)
    private LocalDateTime expiresAt;
    
    @Column(nullable = false)
    private boolean revoked = false;
}
```

#### 8.8.2 Token Expiration
```java
public boolean isValid() {
    return !revoked && LocalDateTime.now().isBefore(expiresAt);
}
```

#### 8.8.3 Token Revocation
```java
@Transactional
public void logout(String username) {
    User user = userRepository.findByUsername(username)
        .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    refreshTokenRepository.revokeAllByUser(user); // Set revoked = true
}
```

### 8.9 Audit Fields (Created/Updated Timestamps)
```java
@CreatedDate
@Column(name = "created_at", nullable = false, updatable = false)
private LocalDateTime createdAt;

@LastModifiedDate
@Column(name = "updated_at")
private LocalDateTime updatedAt;
```
Requires `@EnableJpaAuditing` in configuration.

### 8.10 Database Schema (Postgres)
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(30) NOT NULL,
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMP,
    last_login TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP
);

CREATE TABLE user_roles (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, role)
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    token VARCHAR(512) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_user_username ON users(username);
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_user_status ON users(status);
CREATE INDEX idx_refresh_token ON refresh_tokens(token);
```

### 8.11 Migrations and Versioning
Use Flyway or Liquibase for schema versioning:
```
db/migration/
  V1__create_users_table.sql
  V2__create_refresh_tokens_table.sql
  V3__add_account_lockout_fields.sql
```

---

## 9. Custom Security Components

### 9.1 SecurityConfig Class

#### 9.1.1 @EnableWebSecurity
Enables Spring Security for web application. Imports necessary security configurations.

#### 9.1.2 @EnableMethodSecurity
```java
@EnableMethodSecurity(securedEnabled = true, jsr250Enabled = true)
```
Enables `@PreAuthorize`, `@Secured`, `@RolesAllowed` annotations on methods.

#### 9.1.3 SecurityFilterChain Bean
```java
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http
        .csrf(AbstractHttpConfigurer::disable) // Stateless JWT = no CSRF
        .cors(cors -> cors.configurationSource(corsConfigurationSource()))
        .sessionManagement(session -> 
            session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/auth/**").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated()
        )
        .authenticationProvider(authenticationProvider())
        .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
    return http.build();
}
```

### 9.2 JWT Authentication Filter

#### 9.2.1 OncePerRequestFilter Extension
```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
```
Guarantees filter executes once per request (handles forwards, errors, async).

#### 9.2.2 Token Extraction from Header
```java
private String extractToken(HttpServletRequest request) {
    String authHeader = request.getHeader("Authorization");
    if (authHeader != null && authHeader.startsWith("Bearer ")) {
        return authHeader.substring(7);
    }
    return null;
}
```

#### 9.2.3 Token Validation
```java
JwtClaims claims = jwtTokenService.validateToken(token);
// Throws JwtException if invalid/expired
```

#### 9.2.4 Setting Security Context
```java
UserContext userContext = jwtTokenService.extractUserContext(token);

// Set custom context
SecurityContextHolder.setUserContext(userContext);

// Set Spring Security context
List<SimpleGrantedAuthority> authorities = 
    userContext.getRoles().stream()
        .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
        .collect(Collectors.toList());

UsernamePasswordAuthenticationToken authToken = 
    new UsernamePasswordAuthenticationToken(
        userContext.getUsername(), null, authorities);
        
org.springframework.security.core.context.SecurityContextHolder
    .getContext().setAuthentication(authToken);
```

#### 9.2.5 Error Handling
```java
try {
    // Validate and set context
} catch (JwtException e) {
    log.warn("JWT validation failed: {}", e.getMessage());
    // Don't throw, let request proceed unauthenticated
    // AuthorizationFilter will reject if endpoint requires auth
}
```

### 9.3 UserContext (BitVelocity Custom)

#### 9.3.1 Thread-Local Storage
```java
public class SecurityContextHolder {
    private static final ThreadLocal<UserContext> userContextHolder = new ThreadLocal<>();
    
    public static void setUserContext(UserContext context) {
        userContextHolder.set(context);
    }
    
    public static UserContext getUserContext() {
        return userContextHolder.get();
    }
    
    public static void clear() {
        userContextHolder.remove(); // Prevent memory leaks
    }
}
```

#### 9.3.2 SecurityContextHolder
BitVelocity has custom `SecurityContextHolder` in `bv-common-security` for microservices to access user context without Spring Security dependency.

#### 9.3.3 Accessing User Info in Services
```java
@Service
public class OrderService {
    public Order createOrder(CreateOrderRequest request) {
        UserContext user = SecurityContextHolder.getUserContext();
        String userId = user.getUserId();
        // Use userId for authorization/audit
    }
}
```

### 9.4 AuthenticationService

#### 9.4.1 Registration Logic
```java
@Transactional
public AuthResponse register(RegisterRequest request) {
    // 1. Validate username/email uniqueness
    if (userRepository.existsByUsername(request.getUsername())) {
        throw new UserAlreadyExistsException("Username exists");
    }
    
    // 2. Hash password
    String hashedPassword = passwordEncoder.encode(request.getPassword());
    
    // 3. Create user with default role
    User user = User.builder()
        .username(request.getUsername())
        .email(request.getEmail())
        .password(hashedPassword)
        .roles(Set.of(Role.ROLE_USER))
        .status(AccountStatus.ACTIVE)
        .build();
    userRepository.save(user);
    
    // 4. Generate tokens
    return generateAuthResponse(user);
}
```

#### 9.4.2 Login Logic
```java
@Transactional
public AuthResponse login(LoginRequest request) {
    // 1. Find user
    User user = userRepository.findByUsername(request.getUsername())
        .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    
    // 2. Check lockout
    if (!user.isAccountNonLocked()) {
        throw new AccountLockedException("Account locked until: " + user.getLockedUntil());
    }
    
    // 3. Authenticate via AuthenticationManager
    try {
        authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(
                request.getUsername(), request.getPassword()));
        
        // 4. Reset failed attempts on success
        user.resetFailedAttempts();
        user.setLastLogin(LocalDateTime.now());
        userRepository.save(user);
        
        return generateAuthResponse(user);
        
    } catch (BadCredentialsException e) {
        handleFailedLoginAttempt(user);
        throw e;
    }
}
```

#### 9.4.3 Token Refresh Logic
```java
@Transactional
public AuthResponse refreshToken(RefreshTokenRequest request) {
    // 1. Find refresh token
    RefreshToken refreshToken = refreshTokenRepository
        .findByToken(request.getRefreshToken())
        .orElseThrow(() -> new InvalidTokenException("Invalid refresh token"));
    
    // 2. Validate expiry and revocation
    if (!refreshToken.isValid()) {
        throw new InvalidTokenException("Refresh token expired or revoked");
    }
    
    // 3. Generate new access token (reuse refresh token)
    UserContext userContext = buildUserContext(refreshToken.getUser());
    String newAccessToken = jwtTokenService.generateAccessToken(userContext);
    
    return AuthResponse.builder()
        .accessToken(newAccessToken)
        .refreshToken(refreshToken.getToken()) // Same refresh token
        .expiresIn(accessTokenExpiry)
        .build();
}
```

#### 9.4.4 Logout Logic
```java
@Transactional
public void logout(String username) {
    User user = userRepository.findByUsername(username)
        .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    
    // Revoke all refresh tokens for this user
    refreshTokenRepository.findAllByUser(user)
        .forEach(token -> token.setRevoked(true));
    
    // Access token remains valid until expiry (stateless trade-off)
}
```

### 9.5 Custom Exceptions

#### 9.5.1 Authentication Exceptions
```java
public class UserAlreadyExistsException extends RuntimeException { }
public class AccountLockedException extends RuntimeException { }
```

#### 9.5.2 Authorization Exceptions
```java
public class InsufficientPermissionsException extends RuntimeException { }
```

#### 9.5.3 Token Exceptions
```java
public class InvalidTokenException extends RuntimeException { }
public class TokenExpiredException extends RuntimeException { }
```

### 9.6 Global Exception Handling
```java
@RestControllerAdvice
public class SecurityExceptionHandler {
    
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<ErrorResponse> handleBadCredentials(BadCredentialsException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(new ErrorResponse("Invalid credentials"));
    }
    
    @ExceptionHandler(AccountLockedException.class)
    public ResponseEntity<ErrorResponse> handleAccountLocked(AccountLockedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(new ErrorResponse(e.getMessage()));
    }
    
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException e) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
            .body(new ErrorResponse("Access denied"));
    }
}
```

---

## 10. Session Management

### 10.1 Stateless vs Stateful Sessions
- **Stateful**: Server stores session in memory/DB. Session ID in cookie. Requires sticky sessions in load balancing.
- **Stateless**: No server-side state. JWT contains all user info. Scales horizontally without session affinity.

### 10.2 Session Creation Policy

#### 10.2.1 STATELESS
```java
.sessionManagement(session -> 
    session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
```
Never creates session. Used with JWT. SecurityContext not persisted between requests.

#### 10.2.2 IF_REQUIRED
Default. Creates session only if needed. Used with form login.

#### 10.2.3 ALWAYS
Always creates session, even if not needed. Rarely used.

#### 10.2.4 NEVER
Never creates session, but uses existing if present. Hybrid approach.

### 10.3 Why Stateless for JWT?
- **Scalability**: No session synchronization across instances
- **Microservices**: Each service validates tokens independently
- **Mobile apps**: Simpler client-side storage

Trade-off: Cannot instantly revoke access tokens (must wait for expiry).

### 10.4 Session Fixation Protection
Not applicable for stateless JWT. For session-based auth, Spring Security changes session ID on authentication to prevent fixation attacks.

### 10.5 Concurrent Session Control
Stateful feature: Limit simultaneous sessions per user. Not applicable for JWT (tokens are independent).

### 10.6 Remember-Me Authentication
Session-based feature. For JWT, achieve similar with long-lived refresh tokens stored in HttpOnly cookies.

---

## 11. CORS and CSRF Configuration

### 11.1 Cross-Origin Resource Sharing (CORS)

#### 11.1.1 What is CORS?
Browser security preventing JavaScript from domain A calling API on domain B. Server must explicitly allow cross-origin requests.

#### 11.1.2 CORS Configuration
```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("http://localhost:3000", "https://bitvelocity.com"));
    config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(Arrays.asList("*"));
    config.setExposedHeaders(Arrays.asList("Authorization"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);
    
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

#### 11.1.3 Allowed Origins
Whitelist of domains allowed to call API. `*` allows all (insecure, avoid in production).

#### 11.1.4 Allowed Methods
HTTP methods permitted for cross-origin requests. Always include `OPTIONS` (preflight).

#### 11.1.5 Allowed Headers
Headers frontend can send. `*` allows all. Specific: `["Authorization", "Content-Type"]`.

#### 11.1.6 Exposed Headers
Headers frontend can read from response. Expose `Authorization` for new tokens in response headers.

#### 11.1.7 Credentials Support
```java
config.setAllowCredentials(true);
```
Allows cookies/auth headers in cross-origin requests. Cannot combine with `allowedOrigins("*")` (use specific origins).

### 11.2 Cross-Site Request Forgery (CSRF)

#### 11.2.1 What is CSRF?
Attack where malicious site tricks user's browser into making authenticated request to your API using existing cookies.

#### 11.2.2 CSRF Token Generation
Server generates unique token per session, embeds in form/page. Frontend includes token in requests. Server validates token.

#### 11.2.3 When to Disable CSRF
```java
.csrf(AbstractHttpConfigurer::disable)
```
Safe to disable for stateless JWT (no cookies). CSRF exploits session cookies.

#### 11.2.4 CSRF with JWT
If JWT in Authorization header (not cookie): CSRF not applicable (JavaScript cannot read HttpOnly cookies, attacker cannot get token).

If refresh token in HttpOnly cookie: Enable CSRF for token refresh endpoint.

### 11.3 BitVelocity CORS Configuration
```java
http.cors(cors -> cors.configurationSource(corsConfigurationSource()))
```
Allows `localhost:3000` (React frontend) and `localhost:8081` (product service) to call auth service.

---

## 12. Security Best Practices

### 12.1 Never Log Sensitive Data
```java
// BAD
log.info("Login attempt: username={}, password={}", username, password);
log.debug("JWT token: {}", token);

// GOOD
log.info("Login attempt: username={}", username);
log.debug("JWT token validated for user: {}", username);
```
Passwords, tokens, PII in logs = security breach.

### 12.2 Always Use HTTPS in Production
HTTP transmits data in plain text. Passwords, tokens visible to network sniffers. Enforce HTTPS:
```java
http.requiresChannel(channel -> channel.anyRequest().requiresSecure());
```

### 12.3 Token Storage Best Practices
- **Access token**: Memory (lost on refresh, short-lived anyway)
- **Refresh token**: HttpOnly cookie (XSS-safe) or secure storage API
- **Never**: localStorage for refresh tokens (XSS vulnerability)

### 12.4 Password Policy Enforcement
Validate on frontend AND backend:
```java
@PrePersist
@PreUpdate
private void validatePassword() {
    PasswordValidationResult result = passwordSecurityService.validatePasswordComplexity(password);
    if (!result.isValid()) {
        throw new InvalidPasswordException(result.getErrors());
    }
}
```

### 12.5 Rate Limiting
Prevent brute force attacks:
```java
@RateLimiter(name = "login", fallbackMethod = "loginFallback")
public AuthResponse login(LoginRequest request) { }
```
Use Resilience4j or Redis-based rate limiting (5 attempts per minute per IP).

### 12.6 Account Lockout Strategy
- **After N failures**: Lock account temporarily (30 min)
- **Exponential backoff**: 1st lock = 30 min, 2nd = 1 hour, 3rd = 24 hours
- **Unlock mechanism**: Time-based auto-unlock or admin intervention
- **Notification**: Email user on lockout

### 12.7 Security Headers
```java
http.headers(headers -> headers
    .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
    .xssProtection(xss -> xss.block(true))
    .frameOptions(FrameOptionsConfig::deny)
    .httpStrictTransportSecurity(hsts -> hsts.maxAgeInSeconds(31536000))
);
```

### 12.8 Input Validation
```java
@Valid @RequestBody RegisterRequest request
```
Use Bean Validation (`@NotBlank`, `@Email`, `@Size`). Prevent SQL injection, XSS.

### 12.9 SQL Injection Prevention
Use parameterized queries (JPA/JDBC template auto-escapes):
```java
// Safe (parameterized)
userRepository.findByUsername(username);

// Unsafe (string concatenation)
em.createQuery("SELECT u FROM User u WHERE username = '" + username + "'");
```

### 12.10 XSS Prevention
- **Escape output**: Spring's Thymeleaf auto-escapes
- **Content-Type**: Set correct `Content-Type` headers
- **CSP headers**: Restrict script sources

### 12.11 Dependency Security Scanning
```bash
./mvnw dependency-check:check
```
Use OWASP Dependency Check, Snyk, or GitHub Dependabot.

### 12.12 Regular Security Audits
- Penetration testing
- Code reviews focusing on auth/authz
- Update dependencies (Spring Security patches)
- Monitor CVEs

---

## 13. BitVelocity Implementation Reference

### 13.1 Module Structure

#### 13.1.1 bv-auth-service (Authentication Service)
Centralized auth service. Endpoints: register, login, refresh, logout. Database: users, refresh tokens. Port 8080.

#### 13.1.2 bv-common-auth (Shared Auth Utilities)
Library with `UserContext`, `SecurityContextHolder`, `AuthUtils`. No DB, no HTTP. Used by all services to access authenticated user info.

#### 13.1.3 bv-common-security (Security Components)
JWT utilities (`JwtTokenService`, `JwtProperties`), password security (`PasswordSecurityService`), filters (`JwtAuthenticationFilter`). Shared across services.

### 13.2 Complete Authentication Flow
```
1. User → POST /api/auth/register
   └─ AuthController → AuthenticationService.register()
      └─ Validate uniqueness → Hash password → Save user → Generate tokens
      
2. User → POST /api/auth/login
   └─ AuthController → AuthenticationService.login()
      └─ Find user → Check lockout → AuthenticationManager.authenticate()
         └─ DaoAuthenticationProvider → CustomUserDetailsService.loadUserByUsername()
            └─ UserRepository.findByUsername() → BCryptPasswordEncoder.matches()
               └─ Success: Generate JWT tokens → Return to client
               
3. User → GET /api/products (Authorization: Bearer <token>)
   └─ JwtAuthenticationFilter → Extract token → Validate → Set SecurityContext
      └─ FilterSecurityInterceptor → Check authorization
         └─ ProductController (authenticated) → Process request
```

### 13.3 Registration Endpoint
```bash
POST /api/auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "SecurePass123!"
}

Response 201:
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "username": "john_doe",
    "email": "john@example.com",
    "roles": ["ROLE_USER"]
  }
}
```

### 13.4 Login Endpoint
```bash
POST /api/auth/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "SecurePass123!"
}

Response 200: (same as registration)

Response 401 (bad credentials):
{
  "error": "Invalid credentials",
  "timestamp": "2025-12-31T12:00:00Z"
}

Response 403 (account locked):
{
  "error": "Account locked until: 2025-12-31T12:30:00Z",
  "timestamp": "2025-12-31T12:00:00Z"
}
```

### 13.5 Refresh Token Endpoint
```bash
POST /api/auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJhbGc..."
}

Response 200:
{
  "accessToken": "eyJhbGc...", // New token
  "refreshToken": "eyJhbGc...", // Same token
  "tokenType": "Bearer",
  "expiresIn": 900
}
```

### 13.6 Logout Endpoint
```bash
POST /api/auth/logout
Authorization: Bearer eyJhbGc...

Response 204 No Content
```

### 13.7 Protected Endpoint Example
```java
@RestController
@RequestMapping("/api/products")
public class ProductController {
    
    @GetMapping
    public List<Product> getAllProducts() {
        // No auth required (configured in SecurityConfig)
        return productService.getAllProducts();
    }
    
    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'VENDOR')")
    public Product createProduct(@RequestBody CreateProductRequest request) {
        String userId = SecurityContextHolder.getUserContext().getUserId();
        return productService.createProduct(request, userId);
    }
    
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or @productSecurity.isOwner(#id)")
    public void deleteProduct(@PathVariable String id) {
        productService.deleteProduct(id);
    }
}
```

### 13.8 Configuration Files

#### 13.8.1 application.yml
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/bitvelocity_auth
    username: postgres
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate # Use Flyway for migrations
    show-sql: false

jwt:
  secret: ${JWT_SECRET} # Base64-encoded 256-bit key
  access-token-expiry: 15m
  refresh-token-expiry: 7d
  issuer: bitvelocity
  audience: bitvelocity-services
  clock-skew: 60s

security:
  account-lockout:
    enabled: true
    max-failed-attempts: 5
    lockout-duration-minutes: 30
```

#### 13.8.2 JWT Properties
```java
@ConfigurationProperties(prefix = "jwt")
@Component
public class JwtProperties {
    private String secret;
    private Duration accessTokenExpiry;
    private Duration refreshTokenExpiry;
    private String issuer;
    private String audience;
    private Duration clockSkew;
}
```

#### 13.8.3 Security Properties
Stored in environment variables:
- `JWT_SECRET`: Random 256-bit base64 string
- `DB_PASSWORD`: Database password

Never commit secrets to git. Use environment variables or secret managers (Vault, AWS Secrets Manager).

### 13.9 Database Schema
See Section 8.10 for complete schema.

### 13.10 API Documentation
OpenAPI/Swagger available at `/swagger-ui.html` (permitted in SecurityConfig).

---

## 14. Common Patterns and Anti-Patterns

### 14.1 Common Patterns

#### 14.1.1 Token Refresh Pattern
```java
// Frontend intercepts 401 response
axios.interceptors.response.use(
    response => response,
    async error => {
        if (error.response?.status === 401 && !error.config._retry) {
            error.config._retry = true;
            const refreshToken = getRefreshToken();
            const { accessToken } = await refreshAccessToken(refreshToken);
            setAccessToken(accessToken);
            error.config.headers['Authorization'] = `Bearer ${accessToken}`;
            return axios(error.config);
        }
        return Promise.reject(error);
    }
);
```

#### 14.1.2 Role Hierarchy Pattern
```java
@Bean
public RoleHierarchy roleHierarchy() {
    RoleHierarchyImpl hierarchy = new RoleHierarchyImpl();
    hierarchy.setHierarchy("ROLE_ADMIN > ROLE_MODERATOR > ROLE_USER");
    return hierarchy;
}
```
ADMIN automatically has MODERATOR and USER permissions.

#### 14.1.3 Method Security Pattern
```java
// Controller: Coarse-grained authorization
@PreAuthorize("hasRole('VENDOR')")
public Product createProduct(@RequestBody CreateProductRequest request) {
    return productService.createProduct(request);
}

// Service: Fine-grained business logic
@PreAuthorize("#userId == principal.userId or hasRole('ADMIN')")
public void updateUserProfile(String userId, UpdateProfileRequest request) {
    // Update logic
}
```

#### 14.1.4 Custom Filter Pattern
```java
@Component
@Order(1) // Lower order = earlier in chain
public class RequestLoggingFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(request, response, chain) {
        String requestId = UUID.randomUUID().toString();
        MDC.put("requestId", requestId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}
```

### 14.2 Anti-Patterns to Avoid

#### 14.2.1 Storing Passwords in Plain Text
```java
// NEVER DO THIS
user.setPassword(request.getPassword());

// ALWAYS HASH
user.setPassword(passwordEncoder.encode(request.getPassword()));
```

#### 14.2.2 Ignoring Token Expiration
```java
// BAD: Extract claims without validation
Claims claims = Jwts.parser()
    .setSigningKey(secret)
    .parseClaimsJws(token)
    .getBody(); // Expired tokens pass through

// GOOD: Use parserBuilder with validation
Claims claims = Jwts.parserBuilder()
    .setSigningKey(secret)
    .build()
    .parseClaimsJws(token) // Throws ExpiredJwtException
    .getBody();
```

#### 14.2.3 Weak Password Policies
```java
// BAD: Accepting weak passwords
if (password.length() >= 6) { /* Accept */ }

// GOOD: Enforcing complexity
PasswordValidationResult result = passwordSecurityService.validatePasswordComplexity(password);
if (!result.isValid()) {
    throw new InvalidPasswordException(result.getErrors());
}
```

#### 14.2.4 Mixing Stateful and Stateless
```java
// ANTI-PATTERN: JWT + session creation
http
    .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED))
    .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

// Pick one: Either JWT (stateless) or sessions (stateful)
```

#### 14.2.5 Inadequate Error Handling
```java
// BAD: Leaking information
catch (UsernameNotFoundException e) {
    return ResponseEntity.status(401).body("User not found");
}

// GOOD: Generic error message
catch (UsernameNotFoundException | BadCredentialsException e) {
    return ResponseEntity.status(401).body("Invalid credentials");
}
```
Don't reveal whether username exists (user enumeration attack).

#### 14.2.6 Over-Permissive CORS
```java
// INSECURE
config.setAllowedOrigins(List.of("*"));
config.setAllowCredentials(true); // Won't work with "*" anyway

// SECURE: Specific origins
config.setAllowedOrigins(List.of("https://bitvelocity.com", "http://localhost:3000"));
```

---

## 15. Testing Security

### 15.1 Unit Testing

#### 15.1.1 Testing Password Encoding
```java
@Test
void shouldEncodePassword() {
    String rawPassword = "SecurePass123!";
    String encoded = passwordEncoder.encode(rawPassword);
    
    assertNotEquals(rawPassword, encoded);
    assertTrue(passwordEncoder.matches(rawPassword, encoded));
}

@Test
void shouldNotMatchWrongPassword() {
    String encoded = passwordEncoder.encode("password123");
    assertFalse(passwordEncoder.matches("wrongpassword", encoded));
}
```

#### 15.1.2 Testing JWT Generation
```java
@Test
void shouldGenerateValidAccessToken() {
    UserContext user = new UserContext("123", "john", Set.of("ROLE_USER"));
    String token = jwtTokenService.generateAccessToken(user);
    
    assertNotNull(token);
    JwtClaims claims = jwtTokenService.validateToken(token);
    assertEquals("john", claims.getUsername());
    assertTrue(claims.getRoles().contains("ROLE_USER"));
}
```

#### 15.1.3 Testing Token Validation
```java
@Test
void shouldRejectExpiredToken() {
    String expiredToken = generateExpiredToken();
    assertThrows(ExpiredJwtException.class, 
        () -> jwtTokenService.validateToken(expiredToken));
}

@Test
void shouldRejectMalformedToken() {
    assertThrows(MalformedJwtException.class,
        () -> jwtTokenService.validateToken("invalid.token.here"));
}
```

### 15.2 Integration Testing

#### 15.2.1 @WithMockUser
```java
@Test
@WithMockUser(username = "admin", roles = {"ADMIN"})
void shouldAllowAdminAccess() {
    mockMvc.perform(get("/api/admin/users"))
        .andExpect(status().isOk());
}

@Test
@WithMockUser(username = "user", roles = {"USER"})
void shouldDenyUserAccessToAdmin() {
    mockMvc.perform(get("/api/admin/users"))
        .andExpect(status().isForbidden());
}
```

#### 15.2.2 @WithUserDetails
```java
@Test
@WithUserDetails("john_doe") // Loads from UserDetailsService
void shouldAccessOwnProfile() {
    mockMvc.perform(get("/api/users/john_doe"))
        .andExpect(status().isOk());
}
```

#### 15.2.3 Testing Protected Endpoints
```java
@Test
void shouldRequireAuthentication() {
    mockMvc.perform(get("/api/products"))
        .andExpect(status().isUnauthorized());
}

@Test
void shouldAllowAccessWithValidToken() {
    String token = generateValidToken();
    
    mockMvc.perform(get("/api/products")
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk());
}
```

### 15.3 End-to-End Testing

#### 15.3.1 Registration Flow
```java
@Test
void shouldRegisterNewUser() {
    RegisterRequest request = new RegisterRequest("newuser", "test@example.com", "Pass123!");
    
    webTestClient.post().uri("/api/auth/register")
        .bodyValue(request)
        .exchange()
        .expectStatus().isCreated()
        .expectBody()
        .jsonPath("$.accessToken").exists()
        .jsonPath("$.user.username").isEqualTo("newuser");
}
```

#### 15.3.2 Login Flow
```java
@Test
void shouldLoginAndReceiveTokens() {
    LoginRequest request = new LoginRequest("john_doe", "Pass123!");
    
    AuthResponse response = webTestClient.post().uri("/api/auth/login")
        .bodyValue(request)
        .exchange()
        .expectStatus().isOk()
        .expectBody(AuthResponse.class)
        .returnResult().getResponseBody();
    
    assertNotNull(response.getAccessToken());
    assertNotNull(response.getRefreshToken());
}

@Test
void shouldLockAccountAfterFailedAttempts() {
    LoginRequest request = new LoginRequest("john_doe", "wrongpassword");
    
    // 5 failed attempts
    for (int i = 0; i < 5; i++) {
        webTestClient.post().uri("/api/auth/login")
            .bodyValue(request)
            .exchange()
            .expectStatus().isUnauthorized();
    }
    
    // 6th attempt should return locked status
    webTestClient.post().uri("/api/auth/login")
        .bodyValue(request)
        .exchange()
        .expectStatus().isForbidden()
        .expectBody()
        .jsonPath("$.error").value(containsString("locked"));
}
```

#### 15.3.3 Authorization Checks
```java
@Test
void shouldEnforceRoleBasedAccess() {
    String userToken = loginAsUser();
    String adminToken = loginAsAdmin();
    
    // User cannot access admin endpoint
    webTestClient.get().uri("/api/admin/users")
        .header("Authorization", "Bearer " + userToken)
        .exchange()
        .expectStatus().isForbidden();
    
    // Admin can access
    webTestClient.get().uri("/api/admin/users")
        .header("Authorization", "Bearer " + adminToken)
        .exchange()
        .expectStatus().isOk();
}
```

### 15.4 Security Testing Tools
- **OWASP ZAP**: Automated security scanning
- **Burp Suite**: Manual penetration testing
- **Spring Security Test**: `@WithMockUser`, `@WithUserDetails`
- **Testcontainers**: Integration tests with real database
- **JMeter/Gatling**: Load testing auth endpoints

---

## 16. Troubleshooting Guide

### 16.1 Common Authentication Issues

#### 16.1.1 401 Unauthorized
**Symptom**: Request returns 401 even with token.

**Causes**:
- Token expired
- Invalid signature (wrong secret)
- Token not in `Authorization` header
- Missing `Bearer ` prefix

**Debug**:
```java
log.debug("Token: {}", token);
log.debug("Token expired: {}", jwtTokenService.isTokenExpired(token));
log.debug("SecurityContext: {}", SecurityContextHolder.getContext().getAuthentication());
```

#### 16.1.2 403 Forbidden
**Symptom**: Authenticated but access denied.

**Causes**:
- Insufficient role/authority
- Method-level security blocking access
- CSRF protection enabled (stateless should disable)

**Debug**:
```java
Authentication auth = SecurityContextHolder.getContext().getAuthentication();
log.debug("User: {}, Authorities: {}", auth.getName(), auth.getAuthorities());
```

#### 16.1.3 Invalid Credentials
**Symptom**: Login fails with correct password.

**Causes**:
- Password not hashed during registration
- Wrong `PasswordEncoder` used
- Database field too short (truncated hash)

**Fix**:
```sql
-- Check stored password format
SELECT username, password_hash FROM users WHERE username = 'john';
-- BCrypt hashes start with $2a$ or $2b$ and are 60 chars
```

#### 16.1.4 Token Expired
**Symptom**: Token validation throws `ExpiredJwtException`.

**Solutions**:
- Implement token refresh mechanism
- Increase `access-token-expiry` (security trade-off)
- Frontend should proactively refresh before expiry

### 16.2 Filter Chain Issues
**Symptom**: Custom filter not executing.

**Causes**:
- Filter not registered in `SecurityFilterChain`
- Wrong order (inserted after target filter)
- Filter not annotated with `@Component`

**Fix**:
```java
http.addFilterBefore(customFilter, TargetFilter.class);
```

### 16.3 CORS Errors
**Symptom**: Browser blocks request with CORS error (OPTIONS 403).

**Causes**:
- Missing CORS configuration
- `permitAll()` not applied to OPTIONS requests
- Credentials + wildcard origins

**Fix**:
```java
.cors(cors -> cors.configurationSource(corsConfigurationSource()))
.authorizeHttpRequests(auth -> auth
    .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
    // ... other rules
)
```

### 16.4 UserDetailsService Not Found
**Symptom**: `NoSuchBeanDefinitionException: No qualifying bean of type 'UserDetailsService'`

**Causes**:
- `CustomUserDetailsService` not annotated with `@Service`
- Component scanning not enabled
- Class in wrong package

**Fix**:
```java
@Service
public class CustomUserDetailsService implements UserDetailsService { }

@SpringBootApplication
@EnableJpaAuditing
@ComponentScan(basePackages = "com.bitvelocity")
public class AuthServiceApplication { }
```

### 16.5 Password Encoding Mismatch
**Symptom**: Authentication fails with correct credentials after password change.

**Cause**: Different encoders for encoding vs verification.

**Fix**: Use same `PasswordEncoder` bean everywhere:
```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
}
```

### 16.6 JWT Validation Failures
**Symptom**: Valid token rejected with `SignatureException`.

**Causes**:
- Secret changed (invalidates all tokens)
- Secret not Base64-encoded correctly
- Different secret between services

**Debug**:
```bash
# Decode JWT (header + payload) at jwt.io
echo "eyJhbGc..." | base64 -d
```

### 16.7 Debug Logging Configuration
```yaml
logging:
  level:
    org.springframework.security: DEBUG
    com.bitvelocity.auth: DEBUG
    com.bit.velocity.common.security: DEBUG
```

**Logs show**:
- Filter chain execution
- Authentication attempts
- Authorization decisions
- Exception stack traces

### 16.8 Security Debug Mode
```java
@EnableWebSecurity(debug = true) // Only in development
```
**Output**: Detailed request processing (filters, decisions, exceptions). **Never enable in production** (performance impact, sensitive data in logs).

---

## Appendices

### Appendix A: Key Classes Reference

#### Spring Security Core
- `SecurityContextHolder` - Thread-local authentication storage
- `Authentication` - User identity + authorities
- `UserDetails` - User information contract
- `UserDetailsService` - Load user by username
- `PasswordEncoder` - Password hashing/verification
- `AuthenticationManager` - Orchestrates authentication
- `AuthenticationProvider` - Specific auth mechanism (DAO, LDAP, etc.)
- `GrantedAuthority` - Permission/role representation

#### Filters
- `OncePerRequestFilter` - Base for custom filters (single execution guarantee)
- `UsernamePasswordAuthenticationFilter` - Form login processing
- `BasicAuthenticationFilter` - HTTP Basic auth
- `ExceptionTranslationFilter` - Converts security exceptions to HTTP responses
- `FilterSecurityInterceptor` - Enforces authorization decisions

#### BitVelocity Custom
- `UserContext` (bv-common-security) - User info POJO
- `SecurityContextHolder` (bv-common-security) - Thread-local user context
- `JwtTokenService` (bv-common-security) - JWT generation/validation
- `PasswordSecurityService` (bv-common-security) - Password complexity validation
- `JwtAuthenticationFilter` - Validates JWT, sets context
- `CustomUserDetailsService` - Loads users from database

### Appendix B: Annotations Quick Reference

| Annotation | Purpose | Example |
|------------|---------|---------|
| `@EnableWebSecurity` | Enable Spring Security | On `@Configuration` class |
| `@EnableMethodSecurity` | Enable method-level security | `@EnableMethodSecurity(securedEnabled = true)` |
| `@PreAuthorize` | Check before method execution | `@PreAuthorize("hasRole('ADMIN')")` |
| `@PostAuthorize` | Check after method execution | `@PostAuthorize("returnObject.userId == principal.id")` |
| `@Secured` | Simple role check | `@Secured("ROLE_ADMIN")` |
| `@RolesAllowed` | JSR-250 role check | `@RolesAllowed({"ADMIN", "MODERATOR"})` |
| `@WithMockUser` | Mock user in tests | `@WithMockUser(roles = {"ADMIN"})` |
| `@WithUserDetails` | Load real user in tests | `@WithUserDetails("john_doe")` |

### Appendix C: Configuration Properties

#### JWT Properties (application.yml)
```yaml
jwt:
  secret: ${JWT_SECRET}                   # Base64-encoded 256-bit key
  access-token-expiry: 15m                # Access token lifetime
  refresh-token-expiry: 7d                # Refresh token lifetime
  issuer: bitvelocity                     # Token issuer (iss claim)
  audience: bitvelocity-services          # Token audience (aud claim)
  clock-skew: 60s                         # Tolerate clock differences
```

#### Security Properties
```yaml
security:
  account-lockout:
    enabled: true                         # Enable lockout mechanism
    max-failed-attempts: 5                # Attempts before lockout
    lockout-duration-minutes: 30          # Lockout duration
```

#### CORS Properties
```yaml
cors:
  allowed-origins:
    - http://localhost:3000
    - https://bitvelocity.com
  allowed-methods:
    - GET
    - POST
    - PUT
    - DELETE
    - OPTIONS
  allow-credentials: true
  max-age: 3600
```

### Appendix D: SQL Schema Scripts

#### Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(60) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    failed_login_attempts INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMP,
    last_login TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_username ON users(username);
CREATE INDEX idx_user_email ON users(email);
CREATE INDEX idx_user_status ON users(status);
```

#### User Roles Table
```sql
CREATE TABLE user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL,
    PRIMARY KEY (user_id, role)
);
```

#### Refresh Tokens Table
```sql
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token VARCHAR(512) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_refresh_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_token_user ON refresh_tokens(user_id);
```

### Appendix E: cURL Examples

#### Register
```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "password": "SecurePass123!"
  }'
```

#### Login
```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "password": "SecurePass123!"
  }'
```

#### Access Protected Endpoint
```bash
curl -X GET http://localhost:8080/api/products \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

#### Refresh Token
```bash
curl -X POST http://localhost:8080/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }'
```

#### Logout
```bash
curl -X POST http://localhost:8080/api/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

### Appendix F: Postman Collection

Create collection with environment variables:
```json
{
  "BASE_URL": "http://localhost:8080",
  "ACCESS_TOKEN": "",
  "REFRESH_TOKEN": ""
}
```

**Pre-request script** (auto-set token):
```javascript
pm.request.headers.add({
    key: 'Authorization',
    value: 'Bearer ' + pm.environment.get('ACCESS_TOKEN')
});
```

**Test script** (save tokens):
```javascript
if (pm.response.code === 200) {
    const response = pm.response.json();
    pm.environment.set('ACCESS_TOKEN', response.accessToken);
    pm.environment.set('REFRESH_TOKEN', response.refreshToken);
}
```

### Appendix G: Further Reading

#### Official Documentation
- [Spring Security Reference](https://docs.spring.io/spring-security/reference/)
- [Spring Security Architecture](https://spring.io/guides/topicals/spring-security-architecture)
- [JWT.io Introduction](https://jwt.io/introduction)

#### Books
- *Spring Security in Action* by Laurentiu Spilca
- *OAuth 2 in Action* by Justin Richer & Antonio Sanso

#### RFCs
- [RFC 7519 - JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)
- [RFC 6749 - OAuth 2.0](https://tools.ietf.org/html/rfc6749)
- [RFC 7617 - HTTP Basic Authentication](https://tools.ietf.org/html/rfc7617)

#### Security Resources
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [CWE Top 25 Most Dangerous Software Weaknesses](https://cwe.mitre.org/top25/)

#### BitVelocity Resources
- `bv-auth-service/README.md` - Auth service documentation
- `AUTH_SERVICE_ANALYSIS.md` - Service architecture analysis
- `SECURITY_ARCHITECTURE.md` - BitVelocity security overview
- `BitVelocity-Docs/docs/adr/` - Architecture decision records

---

**Document Complete** ✅

All 16 sections filled with practical, concise content tailored for experienced engineers. Guide covers Spring Security fundamentals through advanced BitVelocity implementations with code examples from your actual codebase.

---

## Document Status

- [ ] Section 1: Introduction to Spring Security
- [ ] Section 2: Spring Security Architecture Overview
- [ ] Section 3: Security Filter Chain Deep Dive
- [ ] Section 4: Authentication Fundamentals
- [ ] Section 5: Authorization and Access Control
- [ ] Section 6: JWT Token Implementation
- [ ] Section 7: Password Security
- [ ] Section 8: Database Integration for User Management
- [ ] Section 9: Custom Security Components
- [ ] Section 10: Session Management
- [ ] Section 11: CORS and CSRF Configuration
- [ ] Section 12: Security Best Practices
- [ ] Section 13: BitVelocity Implementation Reference
- [ ] Section 14: Common Patterns and Anti-Patterns
- [ ] Section 15: Testing Security
- [ ] Section 16: Troubleshooting Guide

---

## How to Use This Guide

1. **Beginners**: Start with Sections 1-2 for fundamentals, then move to Section 4 for authentication basics
2. **Intermediate**: Focus on Sections 3, 5, 6, 7 for filter chains, authorization, JWT, and password security
3. **Advanced**: Deep dive into Sections 9-13 for custom implementations and BitVelocity-specific patterns
4. **Reference**: Use Sections 14-16 and Appendices for quick lookups and troubleshooting

---

**Next Steps**: We will fill in each section systematically, starting with the fundamentals and building up to advanced topics. Each section will include:
- Conceptual explanations
- Code examples from BitVelocity
- Diagrams and flow charts
- Best practices
- Common pitfalls
