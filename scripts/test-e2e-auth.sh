#!/bin/bash

# BitVelocity E2E Authentication Test Script
# Tests: Register → Login → Get Token → Call Product Service → Refresh Token

# Find $JQ_BIN (Homebrew or system)
JQ_BIN=$(which $JQ_BIN 2>/dev/null || echo "$HOME/.homebrew/bin/jq")

BASE_AUTH_URL="http://localhost:8080/api"
BASE_PRODUCT_URL="http://localhost:8081/api"

echo "========================================="
echo "BitVelocity E2E Authentication Test"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0.32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Register User
echo "Step 1: Registering new user..."
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_AUTH_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "testuser@bitvelocity.com",
    "password": "TestPass123!"
  }')

if echo "$REGISTER_RESPONSE" | grep -q "accessToken"; then
  echo -e "${GREEN}✓ User registered successfully${NC}"
  ACCESS_TOKEN=$(echo "$REGISTER_RESPONSE" | $JQ_BIN -r '.accessToken')
  REFRESH_TOKEN=$(echo "$REGISTER_RESPONSE" | $JQ_BIN -r '.refreshToken')
  echo "Access Token: ${ACCESS_TOKEN:0:50}..."
  echo "Refresh Token: ${REFRESH_TOKEN:0:50}..."
else
  echo -e "${RED}✗ Registration failed${NC}"
  echo "$REGISTER_RESPONSE" | $JQ_BIN '.'
  exit 1
fi

echo ""

# Step 2: Get Current User
echo "Step 2: Getting current user info..."
USER_RESPONSE=$(curl -s -X GET "$BASE_AUTH_URL/auth/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$USER_RESPONSE" | grep -q "username"; then
  echo -e "${GREEN}✓ User info retrieved${NC}"
  echo "$USER_RESPONSE" | $JQ_BIN '.'
else
  echo -e "${RED}✗ Failed to get user info${NC}"
  echo "$USER_RESPONSE" | $JQ_BIN '.'
fi

echo ""

# Step 3: Call Product Service (Public Endpoint)
echo "Step 3: Calling product service (public endpoint)..."
PRODUCTS_PUBLIC=$(curl -s -X GET "$BASE_PRODUCT_URL/products?page=0&size=5")

if echo "$PRODUCTS_PUBLIC" | grep -q "content"; then
  echo -e "${GREEN}✓ Public product endpoint accessible${NC}"
  echo "Total products: $(echo "$PRODUCTS_PUBLIC" | $JQ_BIN '.totalElements')"
else
  echo -e "${RED}✗ Failed to access products${NC}"
  echo "$PRODUCTS_PUBLIC" | $JQ_BIN '.'
fi

echo ""

# Step 4: Create Product (Protected Endpoint - Should Fail with ROLE_USER)
echo "Step 4: Creating product with USER role (should fail with 403)..."
CREATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$BASE_PRODUCT_URL/products" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "Test Description",
    "sku": "TEST-001",
    "price": 99.99,
    "stockQuantity": 100,
    "category": "ELECTRONICS",
    "status": "ACTIVE"
  }')

HTTP_STATUS=$(echo "$CREATE_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
if [ "$HTTP_STATUS" = "403" ]; then
  echo -e "${GREEN}✓ Authorization working correctly (403 Forbidden)${NC}"
else
  echo -e "${RED}✗ Expected 403, got $HTTP_STATUS${NC}"
  echo "$CREATE_RESPONSE"
fi

echo ""

# Step 5: Logout
echo "Step 5: Logging out..."
LOGOUT_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$BASE_AUTH_URL/auth/logout" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_STATUS=$(echo "$LOGOUT_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
if [ "$HTTP_STATUS" = "204" ]; then
  echo -e "${GREEN}✓ Logged out successfully${NC}"
else
  echo -e "${RED}✗ Logout failed with status $HTTP_STATUS${NC}"
fi

echo ""

# Step 6: Try to use refresh token after logout (Should Fail)
echo "Step 6: Trying to refresh token after logout (should fail)..."
REFRESH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$BASE_AUTH_URL/auth/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refreshToken\": \"$REFRESH_TOKEN\"}")

HTTP_STATUS=$(echo "$REFRESH_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
if [ "$HTTP_STATUS" = "401" ]; then
  echo -e "${GREEN}✓ Refresh token correctly revoked after logout${NC}"
else
  echo -e "${RED}✗ Expected 401, got $HTTP_STATUS${NC}"
  echo "$REFRESH_RESPONSE"
fi

echo ""
echo "========================================="
echo "E2E Test Complete"
echo "========================================="
